package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 등록할 수 없는 상태의 티켓을 등록하려 한 경우.
 *
 * <p>스텁에서는 "이미 등록 중" 하나뿐이다. v1 에서는 {@code ticket.status != OWNED} 인 경우가 전부
 * 여기로 걸린다 — 발행 전({@code PENDING_MINT} · {@code MINT_FAILED} · {@code REFUNDED}),
 * 이미 등록 중({@code LISTED}), 입장 완료({@code USED}), 회수됨({@code REVOKED}).
 */
public class TicketNotListableException extends BusinessException {

    public TicketNotListableException(Long ticketId, String why) {
        super(TransferErrorCode.TICKET_NOT_LISTABLE,
                TransferErrorCode.TICKET_NOT_LISTABLE.getMessage() + " (ticketId=" + ticketId + ", " + why + ")");
    }
}
