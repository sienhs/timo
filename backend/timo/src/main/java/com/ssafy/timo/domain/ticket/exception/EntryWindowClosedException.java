package com.ssafy.timo.domain.ticket.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 공연 시작 뒤, 입장 QR 발급 창이 닫힌 경우.
 *
 * <p>정확한 공연 시작 시각은 메시지에 담지 않는다. 진단이 필요하면 호출부
 * ({@code EntryPassService})가 로그로 남긴다.
 */
public class EntryWindowClosedException extends BusinessException {

    public EntryWindowClosedException() {
        super(TicketErrorCode.ENTRY_WINDOW_CLOSED);
    }
}
