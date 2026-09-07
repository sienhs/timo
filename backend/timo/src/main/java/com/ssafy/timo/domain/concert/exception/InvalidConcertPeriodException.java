package com.ssafy.timo.domain.concert.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 공연 종료일이 시작일보다 앞선 경우. */
public class InvalidConcertPeriodException extends BusinessException {

    public InvalidConcertPeriodException() {
        super(ConcertErrorCode.INVALID_CONCERT_PERIOD);
    }
}
