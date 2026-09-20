package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.exception.NotificationNotFoundException;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;

/** 알림 읽음 처리. 조회와 달리 쓰기라 서비스를 나눴다. */
@Service
@RequiredArgsConstructor
public class NotificationReadService {

    private final NotificationRepository notificationRepository;
    private final Clock clock;

    /**
     * 내 알림을 읽음으로 바꾼다. 이미 읽은 알림에 다시 불러도 성공이며 읽은 시각은 처음 값을 유지한다.
     * 앱이 알림을 눌렀을 때 요청이 겹치거나 재시도돼도 결과가 같아야 하기 때문이다.
     *
     * @throws NotificationNotFoundException 알림이 없거나 남의 것일 때
     */
    @Transactional
    public void markRead(Long memberId, Long notificationId) {
        int updated = notificationRepository.markRead(notificationId, memberId, LocalDateTime.now(clock));
        if (updated == 0 && !notificationRepository.existsByIdAndMember_Id(notificationId, memberId)) {
            throw new NotificationNotFoundException(notificationId);
        }
    }

    /** 내 알림을 전부 읽음으로 바꾼다. 알림이 하나도 없거나 이미 다 읽었어도 성공이다. */
    @Transactional
    public void markAllRead(Long memberId) {
        notificationRepository.markAllRead(memberId, LocalDateTime.now(clock));
    }
}
