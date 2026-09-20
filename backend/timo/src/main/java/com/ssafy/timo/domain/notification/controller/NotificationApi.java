package com.ssafy.timo.domain.notification.controller;

import com.ssafy.timo.domain.notification.dto.NotificationListRequest;
import com.ssafy.timo.domain.notification.dto.NotificationListResponse;
import com.ssafy.timo.domain.notification.dto.UnreadCountResponse;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;

/**
 * 알림함 API 규약.
 *
 * <p>알림은 수신자의 것이라 요청자를 {@link CurrentMember} 로만 받고, 조회와 갱신 모두 그 회원의 알림으로
 * 한정한다. 알림 id 만으로 접근하면 남의 알림을 읽거나 읽음 처리할 수 있다. 남의 알림은 403 이 아니라
 * 404 로 답한다.
 */
public interface NotificationApi {

    /** 내 알림을 최신순으로 한 페이지. 다음 페이지는 응답의 {@code nextCursor} 를 {@code cursor} 로 준다. */
    @GetMapping
    ResponseEntity<NotificationListResponse> findMine(
            @Valid @ModelAttribute NotificationListRequest request,
            @CurrentMember Long memberId);

    /**
     * 안 읽은 알림 개수. 배지용이라 목록보다 훨씬 자주 불린다. 앱 시작과 포그라운드 복귀 때 한 번만
     * 부르고 폴링하지 않는다. 실시간 갱신은 푸시의 {@code unreadCount} 가 맡는다.
     */
    @GetMapping("/unread-count")
    ResponseEntity<UnreadCountResponse> countUnread(@CurrentMember Long memberId);

    /** 읽음 처리. 이미 읽었어도 204 다. 없거나 남의 알림이면 404. */
    @PatchMapping("/{notificationId}/read")
    ResponseEntity<Void> markRead(@PathVariable Long notificationId, @CurrentMember Long memberId);

    /** 내 알림을 전부 읽음 처리. 알림이 없거나 이미 다 읽었어도 204 다. */
    @PatchMapping("/read-all")
    ResponseEntity<Void> markAllRead(@CurrentMember Long memberId);
}
