package com.ssafy.timo.domain.ticket.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 내 티켓은 맞지만 지금 입장 QR 을 내줄 수 없는 경우.
 *
 * <p>사유를 메시지에 붙인다. 상태 때문인지 시간대 때문인지는 화면에 다르게 안내해야 하는데,
 * 코드를 둘로 나누면 그때마다 게이트·앱 양쪽 목록을 맞춰야 한다. 여기 걸리는 건 전부
 * "아직/이미 아니다" 한 종류라 코드는 하나로 두고 사유만 구체화한다.
 */
public class EntryPassNotIssuableException extends BusinessException {

    public EntryPassNotIssuableException(Long ticketId, String reason) {
        super(TicketErrorCode.ENTRY_PASS_NOT_ISSUABLE,
                TicketErrorCode.ENTRY_PASS_NOT_ISSUABLE.getMessage()
                        + " (ticketId=" + ticketId + ", reason=" + reason + ")");
    }
}
