package com.ssafy.timo.domain.reservation.exception;

import com.ssafy.timo.global.exception.BusinessException;

import java.time.LocalDateTime;

/**
 * 공연 시작 {@value com.ssafy.timo.domain.concert.entity.Concert#BOOKING_CUTOFF_MINUTES}분 전(마감)을
 * 지난 뒤에 예매하려 한 경우. 선점은 그 전에 됐어도 결제 시점에는 막힌다.
 */
public class BookingClosedException extends BusinessException {

    public BookingClosedException(Long concertId, LocalDateTime startDate) {
        super(ReservationErrorCode.BOOKING_CLOSED,
                ReservationErrorCode.BOOKING_CLOSED.getMessage()
                        + " (concertId=" + concertId + ", startDate=" + startDate + ")");
    }
}
