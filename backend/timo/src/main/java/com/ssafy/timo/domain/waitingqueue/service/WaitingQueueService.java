package com.ssafy.timo.domain.waitingqueue.service;

import com.ssafy.timo.domain.waitingqueue.dto.WaitingQueueResponseDto;

public interface WaitingQueueService {
    WaitingQueueResponseDto join(Long concertId, Long memberId);
    WaitingQueueResponseDto status(Long concertId, Long memberId);
    void leave(Long concertId, Long memberId);
}
