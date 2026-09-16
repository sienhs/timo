package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 존재하지 않는 티켓을 참조한 경우. 티켓 도메인 담당과 합의되면 그쪽으로 옮긴다. */
public class TicketNotFoundException extends BusinessException {

    public TicketNotFoundException(Long ticketId) {
        super(TransferErrorCode.TICKET_NOT_FOUND,
                TransferErrorCode.TICKET_NOT_FOUND.getMessage() + " (ticketId=" + ticketId + ")");
    }
}
