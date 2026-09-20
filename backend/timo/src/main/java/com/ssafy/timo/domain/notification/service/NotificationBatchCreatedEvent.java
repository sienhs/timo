package com.ssafy.timo.domain.notification.service;

import java.util.List;

/**
 * 알림이 알림함에 한꺼번에 새로 들어갔다는 사실. 푸시 발송이 이 이벤트를 받아 움직인다.
 *
 * <p>알림마다 이벤트를 하나씩 내면 스케줄러가 수백 건을 넣을 때 발송 작업도 수백 개가 되고, 한 번에
 * 여러 토큰에 보내는 이점이 사라진다. 그래서 {@link NotificationRecorder} 가 한 번 호출로 넣은 알림을
 * 모아 이벤트 하나로 낸다.
 *
 * <p>비어 있는 묶음은 발행하지 않는다. 받았다는 것은 지금 처음 보내는 알림이 하나 이상 있다는 뜻이다.
 *
 * <p>수신자는 커밋 이후({@code AFTER_COMMIT})에 받아야 한다. 트랜잭션이 롤백돼도 푸시는 회수할 수 없어서,
 * 커밋 전에 보내면 알림함에는 없는 알림이 기기에만 뜬다.
 */
public record NotificationBatchCreatedEvent(List<NotificationCreatedEvent> notifications) {

    public NotificationBatchCreatedEvent {
        notifications = List.copyOf(notifications);
    }
}
