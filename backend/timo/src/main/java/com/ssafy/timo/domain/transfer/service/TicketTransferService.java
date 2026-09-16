package com.ssafy.timo.domain.transfer.service;

/**
 * 체결된 양도의 온체인 처리(코인 전송 + NFT 소유권 이전)를 맡는 포트.
 *
 * <p><b>구현체가 없다.</b> 블록체인 연동 방식이 정해지지 않아 인터페이스만 두었다. 컨트랙트
 * ({@code Marketplace} / {@code TicketNFT} / {@code TicketVault})는 작성돼 있으나, 백엔드가 어떤
 * 지갑으로 어떤 순서로 부를지가 미정이다. {@code SmsSender} 와 같은 패턴으로, 방식이 확정되기
 * 전까지 구현체를 갈아 끼울 수 있게 한다.
 *
 * <p>구현체가 없으므로 <b>이 타입을 주입받는 빈을 만들면 기동이 실패한다.</b> 체결 서비스를
 * 붙일 때 아무 일도 하지 않는 구현체를 둘지, 주입 자체를 미룰지 함께 정한다.
 *
 * <p>알려진 제약(연동 시 반드시 다룰 것):
 * <ul>
 *   <li>{@code Marketplace.buy} 는 코인 전송과 NFT 이전을 <b>같은 트랜잭션</b>에서 처리한다.
 *       원자적이라 에스크로가 필요 없고, 한쪽만 성공하는 상태도 없다.</li>
 *   <li>호출 주체는 {@code OPERATOR_ROLE} 을 가진 백엔드 오퍼레이터 지갑이다.
 *       <b>구매자 개인키는 필요 없다.</b> 반면 등록·취소({@code listForTransfer} / {@code delist})는
 *       {@code ownerOf(tokenId) == msg.sender} 를 요구해 판매자 키로 서명해야 한다.</li>
 *   <li>{@code TicketVault} 가 소비한 {@code tradeId}(bytes32)를 기록해 재사용을 막는다.
 *       HTTP 의 {@code Idempotency-Key} 와 어떻게 맞출지는 미정이다.</li>
 *   <li>DB 에서 매물을 {@code SOLD} 로 넘긴 뒤 온체인 호출이 revert 하는 경우의 보상 흐름이 없다.</li>
 *   <li><b>DB 에는 소유자를 옮길 자리가 없다.</b> {@code Ticket} 은 소유자 컬럼 없이
 *       {@code reservation.member} 로 소유자를 말하고, 체결해도 예매 행은 판매자 것으로 남는다.
 *       구매자가 "내 티켓"으로 보게 하려면 온체인 {@code ownerOf} 를 읽든 미러 컬럼을 만들든
 *       티켓 도메인 쪽 결정이 필요하다. 그전까지 <b>체결은 매물·거래 이력만 남기고 끝난다.</b></li>
 *   <li>{@code Ticket} 에 {@code OWNED -> LISTED} 전이 메서드가 없어 등록해도 티켓 상태가 따라오지
 *       않는다. 티켓 도메인 담당에게 요청해 둔 사항이다.</li>
 * </ul>
 *
 * <p>자세한 내용은 {@code others_docs/MARKET_DEFERRED.md} 1 절에 있다.
 */
public interface TicketTransferService {

    /**
     * 티켓의 소유권과 대금을 옮긴다.
     *
     * <p>동기 호출로 선언돼 있지만 <b>반환형은 확정이 아니다.</b> 체결 API 가 202 를 주고
     * {@code ticket_trade.status} 로 진행을 추적하는 구조라, 실제 연동에서는 트랜잭션 해시만 받고
     * 확정은 나중에 따라오는 형태가 될 수 있다. 온체인 방식이 정해지면 함께 정리한다.
     *
     * @param ticketId     양도 대상 티켓
     * @param fromMemberId 판매자
     * @param toMemberId   구매자
     * @param price        체결가. 단위가 확정되지 않아 {@code long} 이다({@code TicketListing.faceValue} 주석)
     */
    TransferResult transfer(long ticketId, long fromMemberId, long toMemberId, long price);
}
