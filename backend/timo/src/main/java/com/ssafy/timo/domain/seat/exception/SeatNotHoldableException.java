package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 남이 선점 중이거나 이미 결제까지 끝난 좌석을 선점하려 한 경우.
 *
 * <p>왜 안 되는지(남의 선점인지, 판매 완료인지)는 응답에 담지 않는다. 좌석을 하나씩 찔러
 * 다른 사람의 선점 현황을 읽어 내는 것을 막기 위해서다. 화면은 좌석 목록을 다시 받아 갱신하면 된다.
 */
public class SeatNotHoldableException extends BusinessException {

    public SeatNotHoldableException(Long seatId) {
        super(SeatErrorCode.SEAT_NOT_HOLDABLE,
                SeatErrorCode.SEAT_NOT_HOLDABLE.getMessage() + " (seatId=" + seatId + ")");
    }
}
