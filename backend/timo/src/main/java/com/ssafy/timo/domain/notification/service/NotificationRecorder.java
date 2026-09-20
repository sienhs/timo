package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

/**
 * 알림을 저장하는 유일한 진입점. 모든 알림 종류가 이 문을 지난다.
 *
 * <p>여기서 두 규칙이 한 번에 지켜진다.
 * <ul>
 *   <li><b>중복 방지.</b> 같은 회원에게 같은 {@code dedupKey} 는 한 번만 들어간다.</li>
 *   <li><b>새로 넣은 건에만 푸시.</b> 실제로 들어간 알림에만 {@link NotificationBatchCreatedEvent} 로
 *       내보낸다. 스케줄러가 같은 창을 여러 번 훑어도 푸시가 한 번만 나가는 근거다.</li>
 * </ul>
 * 규칙이 종류마다 흩어지면 하나만 빠져도 중복 푸시가 나가므로, 새 알림 종류도 반드시 여기를 지난다.
 *
 * <p>푸시는 이 클래스가 보내지 않는다. 이벤트만 발행하고, 커밋 이후에 받는 수신자가 보낸다. 한 번 호출로
 * 넣은 알림은 이벤트 하나로 묶어 내보낸다. 이 메서드들은 호출자의 트랜잭션에 합류하며 없으면 스스로
 * 시작한다. 트랜잭션 밖에서 이벤트를 발행하면 커밋 이후 수신자가 호출되지 않기 때문이다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class NotificationRecorder {

    private final NotificationRepository notificationRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    /**
     * 알림 한 건을 넣는다.
     *
     * @return 새로 넣었으면 true. 이미 있던 알림이거나 회원이 없어 들어가지 못했으면 false
     */
    @Transactional
    public boolean record(Draft draft) {
        Optional<NotificationCreatedEvent> created = insert(draft);
        created.ifPresent(event -> eventPublisher.publishEvent(new NotificationBatchCreatedEvent(List.of(event))));
        return created.isPresent();
    }

    /**
     * 여러 건을 넣는다. 한 건이 중복이어도 나머지는 계속 들어간다. 새로 들어간 알림은 이벤트 하나로 묶어
     * 내보낸다.
     *
     * @return 새로 들어간 건수
     */
    @Transactional
    public int recordAll(Collection<Draft> drafts) {
        List<NotificationCreatedEvent> created = new ArrayList<>();
        for (Draft draft : drafts) {
            insert(draft).ifPresent(created::add);
        }
        if (!created.isEmpty()) {
            eventPublisher.publishEvent(new NotificationBatchCreatedEvent(created));
        }
        return created.size();
    }

    /**
     * 같은 알림을 여러 회원에게 넣는다. 공연 하나를 두고 보유자나 찜한 회원 모두에게 같은 문구·같은
     * 키로 나가는 경우다. 회원마다 본문이 다르면 {@link #recordAll(Collection)} 을 쓴다.
     *
     * @return 새로 들어간 건수
     */
    @Transactional
    public int recordAll(Collection<Long> memberIds, NotificationType type, String body, Long linkId,
                         String dedupKey) {
        List<Draft> drafts = memberIds.stream()
                .map(memberId -> Draft.of(memberId, type, body, linkId, dedupKey))
                .toList();
        return recordAll(drafts);
    }

    /** 알림을 넣고, 새로 들어갔으면 그 내용을 돌려준다. 이벤트 발행은 호출부가 모아서 한다. */
    private Optional<NotificationCreatedEvent> insert(Draft draft) {
        int inserted = notificationRepository.insertIgnore(
                draft.memberId(),
                draft.type().name(),
                draft.body(),
                draft.linkType() == null ? null : draft.linkType().name(),
                draft.linkId(),
                draft.dedupKey(),
                LocalDateTime.now(clock));
        if (inserted != 1) {
            log.debug("알림을 넣지 않음(중복이거나 회원 없음): memberId={}, dedupKey={}",
                    draft.memberId(), draft.dedupKey());
            return Optional.empty();
        }

        // INSERT IGNORE 는 새 행의 id 를 돌려주지 않는다. 푸시 data 에 id 가 필요하므로 유니크 인덱스로 찾는다.
        Long notificationId = notificationRepository
                .findIdByMemberIdAndDedupKey(draft.memberId(), draft.dedupKey())
                .orElseThrow(() -> new IllegalStateException(
                        "방금 넣은 알림을 찾지 못했다: memberId=%d, dedupKey=%s"
                                .formatted(draft.memberId(), draft.dedupKey())));

        return Optional.of(new NotificationCreatedEvent(
                notificationId, draft.memberId(), draft.type(), draft.body(),
                draft.linkType(), draft.linkId()));
    }

    /**
     * 넣을 알림 한 건의 내용.
     *
     * <p>{@link #of} 는 이동 화면을 알림 종류의 기본값으로 정한다. 마켓 알림처럼 같은 종류가 상황에 따라
     * 다른 화면으로 가야 하면 생성자로 {@code linkType} 을 직접 준다.
     */
    public record Draft(Long memberId, NotificationType type, String body, LinkType linkType, Long linkId,
                        String dedupKey) {

        public static Draft of(Long memberId, NotificationType type, String body, Long linkId, String dedupKey) {
            return new Draft(memberId, type, body, type.getLinkType(), linkId, dedupKey);
        }
    }
}
