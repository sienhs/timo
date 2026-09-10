package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 남의 티켓을 등록하거나 남의 매물을 내리려 한 경우. */
public class NotTicketOwnerException extends BusinessException {

    public NotTicketOwnerException(String tokenId) {
        super(TransferErrorCode.NOT_TICKET_OWNER,
                TransferErrorCode.NOT_TICKET_OWNER.getMessage() + " (tokenId=" + tokenId + ")");
    }
}
