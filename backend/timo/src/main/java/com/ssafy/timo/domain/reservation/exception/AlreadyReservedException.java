package com.ssafy.timo.domain.reservation.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 같은 공연의 유효한 주문·티켓을 이미 보유한 계정이 다시 예매한 경우.
 *
 * <p>환불({@code REFUNDED})까지 끝난 주문은 보유로 보지 않는다. 온체인도 {@code revoke} 되면
 * {@code holdsShow} 가 풀려 다시 예매할 수 있다.
 */
public class AlreadyReservedException extends BusinessException {

    public AlreadyReservedException(Long concertId) {
        super(ReservationErrorCode.ALREADY_RESERVED,
                ReservationErrorCode.ALREADY_RESERVED.getMessage() + " (concertId=" + concertId + ")");
    }
}
