package com.ssafy.timo.domain.notification.scheduler;

import com.ssafy.timo.domain.concert.dto.ConcertStartRow;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.notification.entity.NotificationPhase;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.NotificationMessages;
import com.ssafy.timo.domain.notification.service.NotificationRecorder;
import com.ssafy.timo.domain.notification.service.TicketOwnerReader;
import com.ssafy.timo.global.config.notification.NotificationProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

/**
 * 예매한 공연이 다가온다고, 그 티켓을 지금 들고 있는 회원에게 미리 알린다. 세 번 나간다.
 *
 * <pre>
 * 7일 전   공연 날짜의 7일 전 09:00   (D7)
 * 1일 전   공연 날짜의 하루 전 09:00  (D1)
 * 당일     공연 날짜 당일 09:00       (D0)
 * 대상     현재 티켓 보유자 ({@link TicketOwnerReader})
 * 제외     취소된 공연, 이미 시작한 공연
 * 중복 방지  SHOW_REMINDER_D7 | D1 | D0 :concert={공연 id}
 * </pre>
 *
 * <p>알림은 <b>공연 시작 시각이 아니라 공연 날짜</b>를 기준으로 09:00 에 나간다. 공연이 저녁이든 새벽이든
 * 그 날짜의 7일 전, 하루 전, 당일 아침에 간다. 알림 시각이 날짜에 묶여 있어서 SQL 범위 하나로 역산할 수
 * 없고, 그래서 곧 열릴 공연 후보만 시작 시각 범위로 좁힌 뒤(오늘부터 8일 뒤 자정 전까지) 알림 시각이 지금
 * 창 안인지는 공연마다 자바로 정확히 가린다. 예매 오픈 안내({@link ConcertOpenSweep}) 와 같은 방식이다.
 *
 * <p>당일 09:00 알림은 그 시각에 공연이 아직 시작하지 않았을 때만 나간다. 공연이 아침 9시 전에 시작하면
 * 이미 시작한 공연에 "오늘 열려요" 를 보내게 되므로 보내지 않는다. 어떤 시점이든 시작한 공연에는 보내지
 * 않는다.
 *
 * <p>티켓 상태는 보지 않는다. {@link TicketOwnerReader} 가 정한 보유자 그대로다.
 */
@Component
@RequiredArgsConstructor
public class ShowReminderSweep implements NotificationSweep {

    /** 알림이 나가는 시각. */
    private static final LocalTime MORNING = LocalTime.of(9, 0);

    private static final List<NotificationPhase> PHASES =
            List.of(NotificationPhase.D7, NotificationPhase.D1, NotificationPhase.D0);

    /** 후보로 좁힐 시작 시각의 상한, 오늘 날짜에서 며칠 뒤 자정 전까지인가. 7일 전 알림이 가장 멀리 본다. */
    private static final int LOOKAHEAD_DAYS = 8;

    private final ConcertRepository concertRepository;
    private final TicketOwnerReader ticketOwnerReader;
    private final NotificationRecorder notificationRecorder;
    private final NotificationProperties properties;

    @Override
    public String name() {
        return "SHOW_REMINDER";
    }

    @Override
    public int run(LocalDateTime now, int limit) {
        LocalDateTime notBefore = now.minus(properties.catchUp());
        LocalDateTime candidatesUntil = now.toLocalDate().plusDays(LOOKAHEAD_DAYS).atStartOfDay();

        List<ConcertStartRow> candidates =
                concertRepository.findStartRowsBetween(now, candidatesUntil, ConcertStatus.CANCELED);

        int recorded = 0;
        for (ConcertStartRow concert : candidates) {
            if (recorded >= limit) {
                break;
            }
            if (!concert.getStartDate().isAfter(now)) {
                continue; // 이미 시작했다. 범위 경계에 걸린 것이다.
            }
            List<NotificationPhase> due = PHASES.stream()
                    .filter(phase -> isDue(phase, concert.getStartDate(), now, notBefore))
                    .toList();
            if (due.isEmpty()) {
                continue;
            }

            // 보유자는 공연마다 한 번만 읽는다. 시점이 둘 이상 겹쳐도 같은 사람들이다.
            List<Long> holders = ticketOwnerReader.findHolderMemberIds(List.of(concert.getId()))
                    .getOrDefault(concert.getId(), List.of());
            for (NotificationPhase phase : due) {
                if (recorded >= limit) {
                    return recorded;
                }
                recorded += recordForHolders(concert, phase, holders, limit - recorded);
            }
        }
        return recorded;
    }

    /** 알림 시각이 지났고 보정 구간 안인가. */
    private static boolean isDue(NotificationPhase phase, LocalDateTime start, LocalDateTime now,
                                 LocalDateTime notBefore) {
        LocalDateTime sendAt = sendAt(phase, start);
        return !sendAt.isAfter(now) && !sendAt.isBefore(notBefore);
    }

    /** 이 시점의 알림이 나가야 하는 시각. */
    static LocalDateTime sendAt(NotificationPhase phase, LocalDateTime start) {
        return switch (phase) {
            case D7 -> start.toLocalDate().minusDays(7).atTime(MORNING);
            case D1 -> start.toLocalDate().minusDays(1).atTime(MORNING);
            case D0 -> start.toLocalDate().atTime(MORNING);
            default -> throw new IllegalArgumentException("공연 일정 알림에 없는 시점이다: " + phase);
        };
    }

    private int recordForHolders(ConcertStartRow concert, NotificationPhase phase, List<Long> holders,
                                 int remaining) {
        String body = NotificationMessages.showReminder(concert.getTitle(), phase);
        String dedupKey = NotificationType.SHOW_REMINDER.concertKey(phase.name(), concert.getId());

        return SweepLimits.recordUpTo(holders, remaining, slice -> notificationRecorder.recordAll(
                slice, NotificationType.SHOW_REMINDER, body, concert.getId(), dedupKey));
    }
}
