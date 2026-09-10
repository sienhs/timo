package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 존재하지 않는 tokenId 를 참조한 경우. 티켓 도메인이 생기면 그쪽으로 옮긴다. */
public class TicketNotFoundException extends BusinessException {

    public TicketNotFoundException(String tokenId) {
        super(TransferErrorCode.TICKET_NOT_FOUND,
                TransferErrorCode.TICKET_NOT_FOUND.getMessage() + " (tokenId=" + tokenId + ")");
    }
}
