package com.ssafy.timo.domain.reservation.exception;

import com.ssafy.timo.global.exception.BusinessException;

import java.time.LocalDateTime;

/** 공연은 예매 중(ON_SALE)이지만 아직 오픈 시각 전(혹은 오픈·시작 시각이 없어 알 수 없는) 공연을 예매하려 한 경우. */
public class BookingNotOpenException extends BusinessException {

    public BookingNotOpenException(Long concertId, LocalDateTime openAt) {
        super(ReservationErrorCode.BOOKING_NOT_OPEN,
                ReservationErrorCode.BOOKING_NOT_OPEN.getMessage()
                        + " (concertId=" + concertId + ", openAt=" + openAt + ")");
    }
}
