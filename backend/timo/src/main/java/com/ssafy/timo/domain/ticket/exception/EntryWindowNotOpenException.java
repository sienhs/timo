package com.ssafy.timo.domain.ticket.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 공연 시작 전, 아직 입장 QR 발급 창이 열리지 않은 경우.
 *
 * <p>정확한 공연 시작 시각은 메시지에 담지 않는다. 티켓 화면이 이미 보여주고 있어 다시 실을
 * 이유가 없다. 진단이 필요하면 호출부({@code EntryPassService})가 로그로 남긴다.
 */
public class EntryWindowNotOpenException extends BusinessException {

    public EntryWindowNotOpenException() {
        super(TicketErrorCode.ENTRY_WINDOW_NOT_OPEN);
    }
}
