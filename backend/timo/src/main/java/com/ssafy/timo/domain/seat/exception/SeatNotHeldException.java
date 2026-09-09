package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 선점하지 않은 좌석을 점유(결제 확정)하려 한 경우.
 *
 * <p>아무도 잡지 않은 좌석과 <b>내 선점이 만료된</b> 좌석이 여기에 해당한다. 만료된 선점 위에 결제를
 * 얹어 주면 5 분 규칙이 무의미해지므로, 다시 선점하고 결제하도록 거절한다.
 *
 * <p>남이 잡고 있는 좌석은 이 예외가 아니라 {@link SeatHoldNotOwnedException}(403)이다.
 */
public class SeatNotHeldException extends BusinessException {

    public SeatNotHeldException(Long seatId) {
        super(SeatErrorCode.SEAT_NOT_HELD,
                SeatErrorCode.SEAT_NOT_HELD.getMessage() + " (seatId=" + seatId + ")");
    }
}
