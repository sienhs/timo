package com.ssafy.timo.domain.ticket.service;

import java.math.BigInteger;

/**
 * 입장 처리가 DB 에 커밋됐다는 신호. 온체인 반영은 이 뒤에 비동기로 따라간다.
 *
 * @param ticketId 로그 추적용. 팬 앱 입장 완료 푸시에도 실린다
 * @param tokenId  온체인 {@code markUsed} 대상
 * @param ownerMemberId 입장 시점의 티켓 귀속 회원. 양도됐으면 예매자가 아니라 지금 주인이다
 */
public record TicketEnteredEvent(Long ticketId, BigInteger tokenId, Long ownerMemberId) {
}
