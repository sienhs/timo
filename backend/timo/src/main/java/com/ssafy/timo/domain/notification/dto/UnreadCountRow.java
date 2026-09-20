package com.ssafy.timo.domain.notification.dto;

/**
 * 회원 한 명의 안 읽은 알림 개수. 여러 회원의 배지 숫자를 푸시에 실어야 해서 한 번에 묶어 센다.
 * 안 읽은 알림이 없는 회원은 행이 나오지 않는다.
 */
public interface UnreadCountRow {

    Long getMemberId();

    Long getUnreadCount();
}
