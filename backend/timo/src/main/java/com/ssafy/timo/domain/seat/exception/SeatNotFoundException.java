package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 존재하지 않는 좌석을 참조한 경우. */
public class SeatNotFoundException extends BusinessException {

    public SeatNotFoundException(Long seatId) {
        super(SeatErrorCode.SEAT_NOT_FOUND,
                SeatErrorCode.SEAT_NOT_FOUND.getMessage() + " (seatId=" + seatId + ")");
    }
}
