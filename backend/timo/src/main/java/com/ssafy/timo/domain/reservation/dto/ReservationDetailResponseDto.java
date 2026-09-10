package com.ssafy.timo.domain.reservation.dto;

import com.ssafy.timo.domain.reservation.entity.ReservationStatus;

import java.time.LocalDateTime;

/**
 * 주문 상세. 주문 확정 응답과 진행 상태 조회 응답이 같은 모양이다.
 *
 * <p>{@code facePrice} 의 단위는 아직 미확정이다. 컨트랙트는 wei, 현재 백엔드 구역 가격은 원화 정수라
 * 둘을 맞추는 결정이 남아 있다({@code BE_RESERVATION_DOMAIN_DRAFT.md} 7절). 결정 전까지는 구역 가격
 * 정수를 그대로 싣는다.
 *
 * <p>{@code tokenId}·{@code mintTxHash} 는 {@link ReservationStatus#MINTED} 이후에만 값이 있다.
 * {@code failureReason} 은 {@link ReservationStatus#MINT_FAILED}·{@link ReservationStatus#REFUNDED} 에서만 있다.
 */
public record ReservationDetailResponseDto(
        Long id,
        String orderId,
        Long concertId,
        String concertTitle,
        String posterImageUrl,
        LocalDateTime startDate,
        String venueName,
        Long seatId,
        Long sectionId,
        String sectionName,
        int seatNo,
        int seatCol,
        long facePrice,
        ReservationStatus status,
        String tokenId,
        String mintTxHash,
        int mintAttemptCount,
        String failureReason,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {
}
