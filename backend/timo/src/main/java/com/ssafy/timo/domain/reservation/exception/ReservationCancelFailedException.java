package com.ssafy.timo.domain.reservation.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 취소 조건은 만족했지만 온체인 회수·환불 트랜잭션이 실패한 경우.
 *
 * <p>{@code ContractCallException}의 상세(어느 함수였는지, RPC가 뭐라 했는지)는 사용자에게 알릴
 * 이유가 없는 내부 값이라 메시지에 담지 않는다. 호출부({@code ReservationServiceImpl})가 원본 예외를
 * 로그로 남긴다.
 */
public class ReservationCancelFailedException extends BusinessException {

    public ReservationCancelFailedException(Throwable cause) {
        super(ReservationErrorCode.RESERVATION_CANCEL_FAILED);
        initCause(cause);
    }
}
