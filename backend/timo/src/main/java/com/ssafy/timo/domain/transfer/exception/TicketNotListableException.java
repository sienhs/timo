package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 등록할 수 없는 상태의 티켓을 등록하려 한 경우.
 *
 * <p>스텁에서는 "이미 등록 중" 하나뿐이다. 티켓 도메인이 생기면 입장 완료·회수된 티켓도 여기로 걸린다.
 */
public class TicketNotListableException extends BusinessException {

    public TicketNotListableException(Long ticketId, String why) {
        super(TransferErrorCode.TICKET_NOT_LISTABLE,
                TransferErrorCode.TICKET_NOT_LISTABLE.getMessage() + " (ticketId=" + ticketId + ", " + why + ")");
    }
}
