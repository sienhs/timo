package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 남이 선점 중이거나 이미 결제까지 끝난 좌석의 선점을 풀려 한 경우.
 *
 * <p>선점 실패({@link SeatNotHoldableException})와 마찬가지로 왜 안 되는지(남의 선점인지,
 * 판매 완료인지)는 응답에 담지 않는다. 취소 API 를 좌석마다 찔러 남의 선점 현황을 읽어 내는
 * 통로가 되면 안 된다.
 *
 * <p>충돌(409)이 아니라 권한 없음(403)이다. 선점은 "자리가 비어 있어야" 되는 것이라 상태 충돌이지만,
 * 취소는 "내 선점이어야" 되는 것이라 요청자 자격의 문제다.
 */
public class SeatHoldNotOwnedException extends BusinessException {

    public SeatHoldNotOwnedException(Long seatId) {
        super(SeatErrorCode.SEAT_HOLD_NOT_OWNED,
                SeatErrorCode.SEAT_HOLD_NOT_OWNED.getMessage() + " (seatId=" + seatId + ")");
    }
}
