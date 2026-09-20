package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.dto.UnreadCountRow;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.MemberPushNotificationService.MemberPush;
import com.ssafy.timo.domain.notification.service.MemberPushNotificationService.MemberPushResult;
import com.ssafy.timo.global.firebase.PushDelivery;
import com.ssafy.timo.global.firebase.PushMessage;
import com.ssafy.timo.global.firebase.PushResult;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 알림이 알림함에 새로 들어가면 그 알림을 푸시로 보낸다.
 *
 * <p><b>커밋 이후에만 보낸다.</b> 트랜잭션 안에서 보내면 롤백됐을 때 알림함에는 없는 알림이 기기에만 뜬다.
 * 푸시는 회수할 수 없다. 외부 호출이 DB 커넥션을 붙잡는 문제도 있어서 별도 스레드({@code pushExecutor})로
 * 보내, 결제나 스윕이 푸시 발송을 기다리지 않게 한다.
 *
 * <p><b>발송 실패는 알림함이 안전망이다.</b> 실패해도 알림은 이미 저장돼 있으므로 예외를 밖으로 던지지
 * 않는다. 던져 봐야 받을 곳이 없다. 실패는 알림 id, 회원 id, FCM 에러 코드를 한 줄에 남겨 "알림함에는 있는데
 * 푸시만 실패" 를 가려낼 수 있게 한다.
 *
 * <p>여기에 {@code @Transactional} 을 붙이지 않는다. 트랜잭션 이벤트 리스너에 붙이면 스프링이 기동 시점에
 * 예외를 던진다. 필요한 트랜잭션은 각 저장소 호출이 알아서 연다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class NotificationPushListener {

    private final MemberPushNotificationService memberPushNotificationService;
    private final NotificationRepository notificationRepository;
    private final NotificationPushPolicy notificationPushPolicy;

    @Async("pushExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onCreated(NotificationBatchCreatedEvent event) {
        try {
            push(event.notifications());
        } catch (Exception e) {
            log.error("알림 푸시 발송 실패 (count={})", event.notifications().size(), e);
        }
    }

    private void push(List<NotificationCreatedEvent> notifications) {
        Map<Long, Long> unreadByMember = unreadCounts(notifications);

        // 전달 방식(우선순위, 유효 시간, 채널)이 알림 종류마다 다르므로 종류별로 나눠 보낸다.
        Map<NotificationType, List<NotificationCreatedEvent>> byType = notifications.stream()
                .collect(Collectors.groupingBy(NotificationCreatedEvent::type, LinkedHashMap::new,
                        Collectors.toList()));

        byType.forEach((type, sameType) -> {
            PushDelivery delivery = notificationPushPolicy.deliveryOf(type);
            for (List<NotificationCreatedEvent> round : onePerMember(sameType)) {
                List<MemberPush> pushes = round.stream()
                        .map(n -> new MemberPush(n.memberId(), toMessage(n, unreadByMember)))
                        .toList();
                List<MemberPushResult> results = memberPushNotificationService.sendToMembers(pushes, delivery);
                logUndelivered(round, results);
            }
        });
    }

    /** 푸시에 실을 배지 숫자. 커밋 이후에 세므로 방금 들어간 알림까지 포함된다. */
    private Map<Long, Long> unreadCounts(List<NotificationCreatedEvent> notifications) {
        Set<Long> memberIds = notifications.stream()
                .map(NotificationCreatedEvent::memberId)
                .collect(Collectors.toSet());
        return notificationRepository.countUnreadByMemberIds(memberIds).stream()
                .collect(Collectors.toMap(UnreadCountRow::getMemberId, UnreadCountRow::getUnreadCount));
    }

    /**
     * 푸시 {@code data} 는 값이 전부 문자열이어야 한다. 대상이 없으면 빈 문자열이다. 앱은 이
     * {@code notificationId} 로 알림함의 같은 알림을 찾고, {@code unreadCount} 로 배지를 그린다.
     */
    private static PushMessage toMessage(NotificationCreatedEvent notification, Map<Long, Long> unreadByMember) {
        Map<String, String> data = new LinkedHashMap<>();
        data.put("notificationId", String.valueOf(notification.notificationId()));
        data.put("linkType", notification.linkType() == null ? "" : notification.linkType().name());
        data.put("linkId", notification.linkId() == null ? "" : String.valueOf(notification.linkId()));
        data.put("unreadCount", String.valueOf(unreadByMember.getOrDefault(notification.memberId(), 0L)));
        return new PushMessage(notification.body(), data);
    }

    /**
     * 같은 회원의 알림이 여럿이면 여러 번에 나눠 보낸다. 한 번의 단체 발송은 회원당 메시지 하나만 받기
     * 때문에 그대로 넘기면 나중 알림이 앞 알림을 덮어써서 푸시가 사라진다. 보통은 한 번에 끝난다.
     */
    private static List<List<NotificationCreatedEvent>> onePerMember(List<NotificationCreatedEvent> notifications) {
        List<List<NotificationCreatedEvent>> rounds = new ArrayList<>();
        List<Set<Long>> membersInRound = new ArrayList<>();
        for (NotificationCreatedEvent notification : notifications) {
            int index = 0;
            while (index < rounds.size() && membersInRound.get(index).contains(notification.memberId())) {
                index++;
            }
            if (index == rounds.size()) {
                rounds.add(new ArrayList<>());
                membersInRound.add(new HashSet<>());
            }
            rounds.get(index).add(notification);
            membersInRound.get(index).add(notification.memberId());
        }
        return rounds;
    }

    /** 전달되지 않은 기기를 알림 id, 회원 id, 에러 코드와 함께 한 줄씩 남긴다. 토큰은 남기지 않는다. */
    private static void logUndelivered(List<NotificationCreatedEvent> round, List<MemberPushResult> results) {
        Map<Long, Long> notificationIdByMember = round.stream()
                .collect(Collectors.toMap(NotificationCreatedEvent::memberId,
                        NotificationCreatedEvent::notificationId));
        for (MemberPushResult result : results) {
            if (result.outcome() == PushResult.Outcome.SENT) {
                continue;
            }
            log.warn("Push not delivered: notificationId={}, memberId={}, outcome={}, errorCode={}",
                    notificationIdByMember.get(result.memberId()), result.memberId(),
                    result.outcome(), result.errorCode());
        }
    }
}
