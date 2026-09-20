package com.ssafy.timo.domain.notification.controller;

import com.ssafy.timo.domain.notification.dto.NotificationListRequest;
import com.ssafy.timo.domain.notification.dto.NotificationListResponse;
import com.ssafy.timo.domain.notification.dto.UnreadCountResponse;
import com.ssafy.timo.domain.notification.service.NotificationQueryService;
import com.ssafy.timo.domain.notification.service.NotificationReadService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 알림함 API (v1). 규약은 {@link NotificationApi} 에 있다.
 *
 * <p>모든 경로가 인증을 요구한다. {@code SecurityConfig} 의 {@code anyRequest().authenticated()} 가
 * 받으므로 경로를 따로 등록하지 않는다.
 */
@RestController
@RequestMapping("/api/v1/notifications")
@RequiredArgsConstructor
public class NotificationController implements NotificationApi {

    private final NotificationQueryService queryService;
    private final NotificationReadService readService;

    @Override
    public ResponseEntity<NotificationListResponse> findMine(NotificationListRequest request, Long memberId) {
        return ResponseEntity.ok(queryService.findMine(memberId, request));
    }

    @Override
    public ResponseEntity<UnreadCountResponse> countUnread(Long memberId) {
        return ResponseEntity.ok(queryService.countUnread(memberId));
    }

    @Override
    public ResponseEntity<Void> markRead(Long notificationId, Long memberId) {
        readService.markRead(memberId, notificationId);
        return ResponseEntity.noContent().build();
    }

    @Override
    public ResponseEntity<Void> markAllRead(Long memberId) {
        readService.markAllRead(memberId);
        return ResponseEntity.noContent().build();
    }
}
