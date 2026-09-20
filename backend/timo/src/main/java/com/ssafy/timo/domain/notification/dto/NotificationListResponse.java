package com.ssafy.timo.domain.notification.dto;

import java.util.List;

/**
 * 알림 목록 한 페이지.
 *
 * @param nextCursor 다음 요청의 {@code cursor}. 다음 페이지가 없으면 null
 */
public record NotificationListResponse(List<NotificationResponse> items, Long nextCursor, boolean hasNext) {
}
