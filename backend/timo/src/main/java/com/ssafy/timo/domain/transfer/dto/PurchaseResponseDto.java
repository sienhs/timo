package com.ssafy.timo.domain.transfer.dto;

import java.time.LocalDateTime;

/**
 * 양도 구매 체결 결과.
 *
 * <p>대금 수령·소유 이전·판매자 정산이 온체인 단일 트랜잭션이라 응답도 하나다. {@code tradeId} 는 그 멱등키,
 * {@code txHash} 는 트랜잭션 해시다.
 *
 * <p>{@code price} 는 등록가와 반드시 같다. 대금이 컨트랙트를 경유하므로 등록가와 실제 지급액이 갈릴 수 없다.
 * 차감 뒤 잔액은 지갑 도메인이 준다.
 */
public record PurchaseResponseDto(
        String tradeId,
        String txHash,
        String tokenId,
        Long concertId,
        String concertTitle,
        String sectionName,
        int seatNo,
        int seatCol,
        long price,
        LocalDateTime purchasedAt
) {
}
