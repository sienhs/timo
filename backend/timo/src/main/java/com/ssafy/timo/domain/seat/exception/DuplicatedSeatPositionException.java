package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.global.exception.BusinessException;

/**
 * 한 구역의 좌석 목록에 같은 자리가 두 번 들어온 경우.
 *
 * <p>그대로 저장하면 {@code uk_seat_section_position} 제약에 걸려 500 이 되므로 미리 걸러낸다.
 */
public class DuplicatedSeatPositionException extends BusinessException {

    public DuplicatedSeatPositionException(String sectionName, SeatPosition position) {
        super(SeatErrorCode.DUPLICATED_SEAT_POSITION,
                SeatErrorCode.DUPLICATED_SEAT_POSITION.getMessage()
                        + " (section=" + sectionName
                        + ", seatNo=" + position.seatNo()
                        + ", seatCol=" + position.seatCol() + ")");
    }
}
