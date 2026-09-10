package com.ssafy.timo.domain.reservation.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 취소 조건을 만족하지 않는 주문. 사유를 메시지에 실어 화면이 그대로 보여 줄 수 있게 한다. */
public class ReservationNotCancellableException extends BusinessException {

    public ReservationNotCancellableException(Long reservationId, String why) {
        super(ReservationErrorCode.RESERVATION_NOT_CANCELLABLE,
                ReservationErrorCode.RESERVATION_NOT_CANCELLABLE.getMessage()
                        + " (reservationId=" + reservationId + ", " + why + ")");
    }
}
