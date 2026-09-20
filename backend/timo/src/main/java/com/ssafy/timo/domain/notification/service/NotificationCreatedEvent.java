package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.NotificationType;

/**
 * 알림 한 건이 알림함에 새로 들어갔다는 내용. {@link NotificationBatchCreatedEvent} 의 원소로 실려 나간다.
 *
 * <p>{@link NotificationRecorder} 가 알림을 실제로 새로 넣었을 때만 만든다. 이미 있던 알림은 만들지
 * 않으므로, 이것을 받았다는 것은 "지금 처음 보내는 알림" 이라는 뜻이다.
 *
 * @param notificationId 방금 들어간 행의 id. 푸시 {@code data} 로 앱에 전해진다
 * @param body           알림함에 저장된 본문과 같은 문자열. 푸시 본문도 이것을 쓴다
 */
public record NotificationCreatedEvent(
        Long notificationId,
        Long memberId,
        NotificationType type,
        String body,
        LinkType linkType,
        Long linkId) {
}
