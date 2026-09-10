package com.ssafy.timo.domain.reservation.dto;

import com.ssafy.timo.domain.reservation.entity.ReservationStatus;

import java.time.LocalDateTime;

/**
 * 주문 목록 항목. 내 예매 목록 카드에 필요한 것만 담는다.
 *
 * <p>발행 추적 정보(tokenId, 시도 횟수, 실패 사유)는 상세({@link ReservationDetailResponseDto})에만 있다.
 */
public record ReservationSummaryResponseDto(
        Long id,
        Long concertId,
        String concertTitle,
        String posterImageUrl,
        LocalDateTime startDate,
        String venueName,
        String sectionName,
        int seatNo,
        int seatCol,
        long facePrice,
        ReservationStatus status,
        LocalDateTime createdAt
) {
}
