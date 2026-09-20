package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.dto.NotificationListRequest;
import com.ssafy.timo.domain.notification.dto.NotificationListResponse;
import com.ssafy.timo.domain.notification.dto.NotificationResponse;
import com.ssafy.timo.domain.notification.dto.UnreadCountResponse;
import com.ssafy.timo.domain.notification.entity.Notification;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.util.List;

/** 알림함 조회. 모든 조회에 요청자의 회원 id 조건이 붙는다. */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NotificationQueryService {

    private final NotificationRepository notificationRepository;
    private final Clock clock;

    public NotificationListResponse findMine(Long memberId, NotificationListRequest request) {
        int size = request.sizeOrDefault();

        // 다음 페이지가 있는지 알려고 한 건 더 읽는다. 별도의 count 쿼리가 필요 없다.
        List<Notification> rows = notificationRepository.findPageOfMember(
                memberId, request.cursorOrLatest(), PageRequest.of(0, size + 1));

        boolean hasNext = rows.size() > size;
        List<Notification> page = hasNext ? rows.subList(0, size) : rows;
        Long nextCursor = hasNext ? page.get(page.size() - 1).getId() : null;

        List<NotificationResponse> items = page.stream()
                .map(n -> NotificationResponse.from(n, clock.getZone()))
                .toList();
        return new NotificationListResponse(items, nextCursor, hasNext);
    }

    public UnreadCountResponse countUnread(Long memberId) {
        return new UnreadCountResponse(notificationRepository.countByMember_IdAndReadAtIsNull(memberId));
    }
}
