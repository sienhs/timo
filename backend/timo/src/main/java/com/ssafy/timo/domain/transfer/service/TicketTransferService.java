package com.ssafy.timo.domain.transfer.service;

/**
 * 체결된 양도의 온체인 처리(코인 전송 + NFT 소유권 이전)를 맡는 포트. {@code SmsSender} 와 같은
 * 패턴이라 값만 받고 도메인 엔티티에는 기대지 않는다.
 *
 * <p>구현체({@code TicketTransferServiceImpl})는 {@code Marketplace.buy} 하나로 끝난다 - 코인 전송과
 * NFT 이전이 같은 온체인 트랜잭션에 묶여 있어 원자적이고, 한쪽만 성공하는 상태가 없다. 호출 주체는
 * {@code OPERATOR_ROLE} 을 가진 백엔드 오퍼레이터 지갑이라 구매자 개인키는 필요 없다.
 *
 * <p><b>호출부(동기)가 실패를 그대로 감당한다.</b> {@link PurchaseService} 가 DB 를 아무것도 바꾸기
 * 전에 이 메서드를 부르고, 여기서 던진 예외를 그대로 맞아 응답만 실패로 끝낸다 - 그래서 "DB 는
 * 팔렸다는데 체인은 모른다" 는 어긋난 상태 자체가 생기지 않는다.
 *
 * <ul>
 *   <li>{@code ContractRevertException} - 온체인이 명시적으로 거부함(예: 구매자가 그새 같은 공연
 *       티켓을 보유하게 됨). 재시도해도 같은 이유로 또 거부된다.</li>
 *   <li>그 외 {@code ContractCallException} - 전송 실패·네트워크 오류 등 일시적일 수 있는 실패.</li>
 * </ul>
 */
public interface TicketTransferService {

    /**
     * 티켓의 소유권과 대금을 옮긴다. 실패하면 예외를 던진다 - {@link TicketTransferService} 클래스
     * 주석의 두 갈래를 본다.
     *
     * <p>{@code listingId} 를 받는 이유는 온체인 {@code tradeId}(bytes32) 를 여기서 결정적으로
     * 유도하기 위해서다 - 매물 하나는 평생 한 번만 팔리므로({@code uk_ticket_trade_listing})
     * {@code listingId} 가 곧 이 체결의 고유 키다.
     *
     * @param listingId      체결 대상 매물. tradeId 유도에 쓴다
     * @param ticketId       양도 대상 티켓
     * @param sellerMemberId 판매자
     * @param buyerMemberId  구매자
     * @param price          체결가. 단위가 확정되지 않아 {@code long} 이다({@code TicketListing.faceValue} 주석)
     */
    TransferResult transfer(long listingId, long ticketId, long sellerMemberId, long buyerMemberId, long price);
}
