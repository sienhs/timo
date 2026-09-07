package com.ssafy.timo.domain.concert.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 존재하지 않는 공연을 조회한 경우. */
public class ConcertNotFoundException extends BusinessException {

    public ConcertNotFoundException(Long concertId) {
        super(ConcertErrorCode.CONCERT_NOT_FOUND,
                ConcertErrorCode.CONCERT_NOT_FOUND.getMessage() + " (concertId=" + concertId + ")");
    }
}
