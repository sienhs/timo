package com.ssafy.timo.domain.reservation.exception;

import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.global.exception.BusinessException;

/**
 * 예매 진행 중({@link ConcertStatus#ON_SALE})이 아닌 공연을 예매하려 한 경우. 등록만 된 공연·매진·종료·취소 전부.
 * ON_SALE 이지만 오픈 전이거나 마감 후인 경우는 {@link BookingNotOpenException}·{@link BookingClosedException} 이 따로 맡는다.
 */
public class ConcertNotOnSaleException extends BusinessException {

    public ConcertNotOnSaleException(Long concertId, ConcertStatus status) {
        super(ReservationErrorCode.CONCERT_NOT_ON_SALE,
                ReservationErrorCode.CONCERT_NOT_ON_SALE.getMessage()
                        + " (concertId=" + concertId + ", status=" + status + ")");
    }
}
