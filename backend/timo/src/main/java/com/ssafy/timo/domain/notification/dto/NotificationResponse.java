package com.ssafy.timo.domain.notification.dto;

import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.Notification;
import com.ssafy.timo.domain.notification.entity.NotificationType;

import java.time.OffsetDateTime;
import java.time.ZoneId;

/**
 * 알림함의 알림 한 건.
 *
 * @param body   개행이 들어갈 수 있다. 앱이 여러 줄로 그려야 한다
 * @param linkId {@code linkType} 에 따라 없을 수 있다
 * @param read   서버가 읽은 시각의 유무로 계산해 내려 준다
 */
public record NotificationResponse(
        Long notificationId,
        NotificationType type,
        String body,
        LinkType linkType,
        Long linkId,
        boolean read,
        OffsetDateTime createdAt) {

    /** 시각은 오프셋을 붙여 내려 앱이 시간대를 짐작하지 않게 한다. {@code zone} 은 서버가 저장에 쓴 시간대다. */
    public static NotificationResponse from(Notification notification, ZoneId zone) {
        return new NotificationResponse(
                notification.getId(),
                notification.getType(),
                notification.getBody(),
                notification.getLinkType(),
                notification.getLinkId(),
                notification.isRead(),
                notification.getCreatedAt().atZone(zone).toOffsetDateTime());
    }
}
