package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.global.exception.BusinessException;

/** 좌석 자리가 구역이 선언한 배치도 격자 크기를 벗어난 경우. */
public class SeatPositionOutOfBoundsException extends BusinessException {

    public SeatPositionOutOfBoundsException(String sectionName,
                                            SeatPosition position,
                                            Integer rowCount,
                                            Integer seatPerRow) {
        super(SeatErrorCode.SEAT_POSITION_OUT_OF_BOUNDS,
                SeatErrorCode.SEAT_POSITION_OUT_OF_BOUNDS.getMessage()
                        + " (section=" + sectionName
                        + ", seatNo=" + position.seatNo()
                        + ", seatCol=" + position.seatCol()
                        + ", rowCount=" + rowCount
                        + ", seatPerRow=" + seatPerRow + ")");
    }
}
