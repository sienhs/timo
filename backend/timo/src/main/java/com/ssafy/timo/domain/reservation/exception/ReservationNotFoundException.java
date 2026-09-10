package com.ssafy.timo.domain.reservation.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 존재하지 않는 주문을 조회한 경우. 남의 주문도 존재를 알리지 않기 위해 같은 예외를 쓴다. */
public class ReservationNotFoundException extends BusinessException {

    public ReservationNotFoundException(Long reservationId) {
        super(ReservationErrorCode.RESERVATION_NOT_FOUND,
                ReservationErrorCode.RESERVATION_NOT_FOUND.getMessage() + " (reservationId=" + reservationId + ")");
    }
}
