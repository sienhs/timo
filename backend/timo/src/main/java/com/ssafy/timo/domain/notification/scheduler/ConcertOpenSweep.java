package com.ssafy.timo.domain.notification.scheduler;

import com.ssafy.timo.domain.concert.dto.ConcertOpenRow;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.notification.entity.NotificationPhase;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.NotificationMessages;
import com.ssafy.timo.domain.notification.service.NotificationRecorder;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.global.config.NotificationProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;

/**
 * 찜한 공연의 예매가 곧 열린다고 미리 알린다. 세 번 나간다.
 *
 * <pre>
 * 7일 전   오픈 날짜의 7일 전 09:00   (D7)
 * 1일 전   오픈 날짜의 하루 전 09:00  (D1)
 * 1시간 전 오픈 시각의 1시간 전       (H1)
 * 대상     그 공연을 찜한 회원
 * 제외     취소된 공연, 이미 열린 공연
 * 중복 방지  CONCERT_OPEN_D7 | D1 | H1 :concert={공연 id}
 * </pre>
 *
 * <p><b>오픈 당일 09:00 과 오픈 시각 자체에는 알림이 없다.</b> 요구사항이 오픈 1시간 전 하나만 정해서다.
 *
 * <p>7일 전과 1일 전은 <b>오픈 시각이 아니라 오픈 날짜</b>를 기준으로 09:00 에 나간다. 오픈이 밤 8시든
 * 새벽 0시 반이든 알림은 그 날짜의 7일 전, 하루 전 아침에 간다. "7일 x 24시간" 으로 빼면 오픈 시각에 따라
 * 알림이 새벽이나 한밤중에 나간다.
 *
 * <p>알림 시각이 날짜에 묶여 있어서 T10 처럼 SQL 범위 하나로 역산할 수 없다. 그래서 곧 열릴 공연 후보만
 * 오픈 시각 범위로 좁힌 뒤(오늘부터 8일 뒤 자정 전까지. 그 밖의 공연은 어느 알림 시각도 아직 안 왔다),
 * 알림 시각이 지금~보정 구간 안인지는 공연마다 자바로 정확히 가린다. 후보는 많아야 수십 개다.
 *
 * <p>보정 구간에서 늦게 나가면 문구가 조금 어긋날 수 있다. 특히 1시간 전 알림이 40분 늦게 나가면
 * "1시간 뒤" 라고 쓰지만 실제로는 20분 남았다. 다만 알림이 아예 안 가는 것보다 낫다고 보고 보정 구간 안에서는
 * 보낸다. 이미 열린 공연에는 어떤 경우에도 보내지 않는다.
 */
@Component
@RequiredArgsConstructor
public class ConcertOpenSweep implements NotificationSweep {

    /** 7일 전, 1일 전 알림이 나가는 시각. */
    private static final LocalTime MORNING = LocalTime.of(9, 0);

    /** 이 스윕이 보내는 시점들. 오픈 당일 09:00 은 요구사항에 없다. */
    private static final List<NotificationPhase> PHASES =
            List.of(NotificationPhase.D7, NotificationPhase.D1, NotificationPhase.H1);

    /** 후보로 좁힐 오픈 시각의 상한, 오늘 날짜에서 며칠 뒤 자정 전까지인가. 7일 전 알림이 가장 멀리 본다. */
    private static final int LOOKAHEAD_DAYS = 8;

    private final ConcertRepository concertRepository;
    private final ConcertWishRepository concertWishRepository;
    private final NotificationRecorder notificationRecorder;
    private final NotificationProperties properties;

    @Override
    public String name() {
        return "CONCERT_OPEN";
    }

    @Override
    public int run(LocalDateTime now, int limit) {
        LocalDateTime notBefore = now.minus(properties.catchUp());
        LocalDateTime candidatesUntil = now.toLocalDate().plusDays(LOOKAHEAD_DAYS).atStartOfDay();

        List<ConcertOpenRow> candidates =
                concertRepository.findOpenRowsBetween(now, candidatesUntil, ConcertStatus.CANCELED);

        int recorded = 0;
        for (ConcertOpenRow concert : candidates) {
            if (!concert.getOpenAt().isAfter(now)) {
                continue; // 이미 열렸다. 범위 경계에 걸린 것이다.
            }
            for (NotificationPhase phase : PHASES) {
                if (recorded >= limit) {
                    return recorded;
                }
                LocalDateTime sendAt = sendAt(phase, concert.getOpenAt());
                if (sendAt.isAfter(now) || sendAt.isBefore(notBefore)) {
                    continue;
                }
                recorded += recordForWishers(concert, phase, limit - recorded);
            }
        }
        return recorded;
    }

    /** 이 시점의 알림이 나가야 하는 시각. */
    static LocalDateTime sendAt(NotificationPhase phase, LocalDateTime openAt) {
        return switch (phase) {
            case D7 -> openAt.toLocalDate().minusDays(7).atTime(MORNING);
            case D1 -> openAt.toLocalDate().minusDays(1).atTime(MORNING);
            case H1 -> openAt.minusHours(1);
            default -> throw new IllegalArgumentException("예매 오픈 안내에 없는 시점이다: " + phase);
        };
    }

    private int recordForWishers(ConcertOpenRow concert, NotificationPhase phase, int remaining) {
        List<Long> wishers = concertWishRepository.findMemberIdsByConcertId(concert.getId());
        String body = NotificationMessages.concertOpen(concert.getTitle(), phase);
        String dedupKey = NotificationType.CONCERT_OPEN_REMINDER.concertKey(phase.name(), concert.getId());

        return SweepLimits.recordUpTo(wishers, remaining, slice -> notificationRecorder.recordAll(
                slice, NotificationType.CONCERT_OPEN_REMINDER, body, concert.getId(), dedupKey));
    }
}
