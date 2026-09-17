package com.ssafy.timo.domain.ticket.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 내 티켓은 맞지만 입장 QR 을 낼 수 있는 상태가 아닌 경우.
 *
 * <p>어떤 상태였는지({@code TicketStatus})는 사용자에게 알려줄 이유가 없는 내부 값이라 메시지에
 * 담지 않는다. 진단이 필요하면 호출부({@code EntryPassService})가 로그로 남긴다.
 */
public class TicketStatusNotIssuableException extends BusinessException {

    public TicketStatusNotIssuableException() {
        super(TicketErrorCode.TICKET_STATUS_NOT_ISSUABLE);
    }
}
