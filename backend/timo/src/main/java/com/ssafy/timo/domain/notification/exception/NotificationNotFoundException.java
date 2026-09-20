package com.ssafy.timo.domain.notification.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 알림이 없거나, 요청자의 것이 아닌 경우.
 *
 * <p>남의 알림을 403 이 아니라 404 로 답한다. 403 은 "그 번호의 알림은 있다" 를 알려주는 셈이라,
 * 번호를 훑어 남의 알림 존재를 알아낼 수 있다. {@code TicketNotFoundException} 과 같은 규칙이다.
 */
public class NotificationNotFoundException extends BusinessException {

    public NotificationNotFoundException(Long notificationId) {
        super(NotificationErrorCode.NOTIFICATION_NOT_FOUND,
                NotificationErrorCode.NOTIFICATION_NOT_FOUND.getMessage()
                        + " (notificationId=" + notificationId + ")");
    }
}
