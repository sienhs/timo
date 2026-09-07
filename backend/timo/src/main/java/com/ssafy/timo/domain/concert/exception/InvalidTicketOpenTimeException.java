package com.ssafy.timo.domain.concert.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 예매 오픈 시각이 공연 시작 이후인 경우. */
public class InvalidTicketOpenTimeException extends BusinessException {

    public InvalidTicketOpenTimeException() {
        super(ConcertErrorCode.INVALID_TICKET_OPEN_TIME);
    }
}
