package com.ssafy.timo.domain.notification.dto;

/** 안 읽은 알림 개수. 앱 아이콘의 배지에 쓴다. */
public record UnreadCountResponse(long unreadCount) {
}
