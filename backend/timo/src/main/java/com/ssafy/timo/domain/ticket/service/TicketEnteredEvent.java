package com.ssafy.timo.domain.ticket.service;

import java.math.BigInteger;

/**
 * 입장 처리가 DB 에 커밋됐다는 신호. 온체인 반영은 이 뒤에 비동기로 따라간다.
 *
 * @param ticketId 로그 추적용
 * @param tokenId  온체인 {@code markUsed} 대상
 */
public record TicketEnteredEvent(Long ticketId, BigInteger tokenId) {
}
