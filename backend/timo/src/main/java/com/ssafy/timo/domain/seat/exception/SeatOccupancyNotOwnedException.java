package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 남이 결제까지 끝낸 좌석의 점유를 풀려 한 경우.
 *
 * <p>누가 점유하고 있는지는 응답에 담지 않는다. 좌석을 하나씩 찔러 남의 예매 현황을 읽어 내는
 * 통로가 되면 안 된다.
 */
public class SeatOccupancyNotOwnedException extends BusinessException {

    public SeatOccupancyNotOwnedException(Long seatId) {
        super(SeatErrorCode.SEAT_OCCUPANCY_NOT_OWNED,
                SeatErrorCode.SEAT_OCCUPANCY_NOT_OWNED.getMessage() + " (seatId=" + seatId + ")");
    }
}
