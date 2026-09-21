package com.ssafy.timo.domain.waitingqueue.dto;

import java.time.Instant;

/** 공연별 예매 입장 대기열 상태. admissionToken은 ADMITTED일 때만 내려간다. */
public record WaitingQueueResponseDto(
        String status,
        Long waitingAhead,
        String admissionToken,
        Instant admissionExpiresAt
) {
}
