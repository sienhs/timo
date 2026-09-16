package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 남의 티켓을 등록하려 한 경우.
 *
 * <p>남의 <b>매물</b>을 내리려 한 경우는 {@link NotListingSellerException} 이다. 화면에 보여 줄
 * 말이 달라 나누어 둔다.
 *
 * <p>소유자 판정은 {@code ticket.reservation.member} 로 한다. {@code Ticket} 에는 소유자 컬럼이 없고,
 * 소유권의 정본은 온체인 {@code TicketNFT} 다. 즉 <b>이 검증은 "이 티켓을 예매한 사람인가"</b>이며,
 * 양도로 주인이 바뀐 티켓까지 가리지는 못한다(체결해도 예매 행은 판매자 것으로 남는다).
 * 온체인 연동 시 {@code ownerOf(tokenId)} 확인이 함께 들어가야 한다.
 */
public class NotTicketOwnerException extends BusinessException {

    public NotTicketOwnerException(Long ticketId) {
        super(TransferErrorCode.NOT_TICKET_OWNER,
                TransferErrorCode.NOT_TICKET_OWNER.getMessage() + " (ticketId=" + ticketId + ")");
    }
}
