package com.ssafy.timo.domain.ticket.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 티켓이 없거나, 요청자의 것이 아닌 경우.
 *
 * <p>남의 티켓을 403 이 아니라 404 로 답한다. 403 은 "그 번호의 티켓은 있다" 를 알려주는 셈이라,
 * 번호를 훑어 누가 어느 공연을 예매했는지 세어 볼 수 있다. 주문 조회
 * ({@code ReservationNotFoundException}) 와 같은 규칙이다.
 */
public class TicketNotFoundException extends BusinessException {

    public TicketNotFoundException(Long ticketId) {
        super(TicketErrorCode.TICKET_NOT_FOUND,
                TicketErrorCode.TICKET_NOT_FOUND.getMessage() + " (ticketId=" + ticketId + ")");
    }
}
