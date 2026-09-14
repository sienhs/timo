package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 남의 티켓을 등록하려 한 경우.
 *
 * <p>남의 <b>매물</b>을 내리려 한 경우는 {@link NotListingSellerException} 이다. 화면에 보여 줄
 * 말이 달라 나누어 둔다.
 */
public class NotTicketOwnerException extends BusinessException {

    public NotTicketOwnerException(Long ticketId) {
        super(TransferErrorCode.NOT_TICKET_OWNER,
                TransferErrorCode.NOT_TICKET_OWNER.getMessage() + " (ticketId=" + ticketId + ")");
    }
}
