package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 결제까지 끝나지 않은(선점 상태인) 좌석의 점유를 풀려 한 경우.
 *
 * <p>점유 해제는 예매 취소의 뒷단이다. 결제도 안 된 좌석에 예매 취소가 들어왔다면 데이터가 어긋난
 * 것이므로 조용히 넘기지 않고 알린다. 선점 취소({@code DELETE .../hold})와 달리 이 경우를
 * 멱등 성공으로 다루지 않는 이유가 여기에 있다.
 *
 * <p>아무도 잡지 않은 좌석은 이미 빈 자리이므로 예외가 아니다.
 */
public class SeatNotOccupiedException extends BusinessException {

    public SeatNotOccupiedException(Long seatId) {
        super(SeatErrorCode.SEAT_NOT_OCCUPIED,
                SeatErrorCode.SEAT_NOT_OCCUPIED.getMessage() + " (seatId=" + seatId + ")");
    }
}
