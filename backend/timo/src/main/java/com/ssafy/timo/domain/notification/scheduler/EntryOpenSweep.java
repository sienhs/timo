package com.ssafy.timo.domain.notification.scheduler;

import com.ssafy.timo.domain.concert.dto.ConcertStartRow;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.NotificationMessages;
import com.ssafy.timo.domain.notification.service.NotificationRecorder;
import com.ssafy.timo.domain.notification.service.TicketOwnerReader;
import com.ssafy.timo.global.config.NotificationProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 공연 시작 2시간 전, 그 공연 티켓을 지금 들고 있는 회원에게 "지금부터 입장할 수 있어요" 를 보낸다.
 *
 * <pre>
 * 알림 시각  공연 시작 - 2시간
 * 시간 창    시작 시각이 [now + 1시간, now + 2시간]   (2시간 전 + 보정 1시간)
 * 대상       현재 티켓 보유자 ({@link TicketOwnerReader})
 * 제외       취소된 공연
 * 중복 방지  ENTRY_OPEN:concert={공연 id}
 * </pre>
 *
 * <p>알림 시각을 SQL 에서 계산하지 않고 여기서 시작 시각의 범위로 바꿔 넘긴다. 컬럼에 함수를 걸면 인덱스를
 * 못 탄다. "알림 시각이 지났고 보정 구간 안이다" 는 "시작이 지금부터 2시간 안이고 (2시간 - 보정 구간) 이후다"
 * 와 같은 말이다.
 *
 * <p><b>2시간은 입장 QR 이 열리는 시각과 같아야 한다.</b> 다르면 "입장할 수 있어요" 를 받고 QR 이 안 나오거나,
 * QR 이 나오는데 알림이 늦는다. 값의 원본은 {@code EntryPassService} 에 있고, 두 값이 같은지 테스트가 지킨다.
 *
 * <p>티켓 상태는 보지 않는다. 발행 대기나 실패 상태의 보유자도 받는데, 공연 2시간 전까지 그 상태로 남는
 * 경우는 드물고, 알림을 보고 앱에 들어오면 티켓 상태가 그대로 보인다.
 */
@Component
@RequiredArgsConstructor
public class EntryOpenSweep implements NotificationSweep {

    /** 입장이 열리는, 공연 시작 전 시간. {@code EntryPassService.ENTRY_OPENS_BEFORE_START} 와 같아야 한다. */
    public static final Duration ENTRY_OPENS_BEFORE_START = Duration.ofHours(2);

    private final ConcertRepository concertRepository;
    private final TicketOwnerReader ticketOwnerReader;
    private final NotificationRecorder notificationRecorder;
    private final NotificationProperties properties;

    @Override
    public String name() {
        return "ENTRY_OPEN";
    }

    @Override
    public int run(LocalDateTime now, int limit) {
        // 알림 시각이 지났다: 시작 - 2시간 <= now  →  시작 <= now + 2시간
        LocalDateTime latestStart = now.plus(ENTRY_OPENS_BEFORE_START);
        // 보정 구간 안이다: 시작 - 2시간 >= now - 보정 구간  →  시작 >= now + 2시간 - 보정 구간.
        // 보정 구간이 2시간보다 길면 이미 시작한 공연까지 걸리므로 지금 이후로 자른다. 시작한 공연에
        // 입장하라는 알림을 보낼 이유가 없다.
        LocalDateTime earliestStart = latestStart.minus(properties.catchUp());
        if (earliestStart.isBefore(now)) {
            earliestStart = now;
        }

        List<ConcertStartRow> concerts =
                concertRepository.findStartRowsBetween(earliestStart, latestStart, ConcertStatus.CANCELED);

        int recorded = 0;
        for (ConcertStartRow concert : concerts) {
            if (recorded >= limit) {
                break;
            }
            recorded += recordForHolders(concert, limit - recorded);
        }
        return recorded;
    }

    private int recordForHolders(ConcertStartRow concert, int remaining) {
        List<Long> holders = ticketOwnerReader.findHolderMemberIds(List.of(concert.getId()))
                .getOrDefault(concert.getId(), List.of());
        String body = NotificationMessages.entryOpen(concert.getTitle());
        String dedupKey = NotificationType.ENTRY_OPEN.concertKey(concert.getId());

        return SweepLimits.recordUpTo(holders, remaining, slice -> notificationRecorder.recordAll(
                slice, NotificationType.ENTRY_OPEN, body, concert.getId(), dedupKey));
    }
}
