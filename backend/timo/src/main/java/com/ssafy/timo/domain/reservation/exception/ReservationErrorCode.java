package com.ssafy.timo.domain.reservation.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum ReservationErrorCode implements BaseErrorCode {

    RESERVATION_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 주문입니다."),
    /** "한 계정은 하나의 공연에서 티켓을 1매만 보유할 수 있다." 온체인 {@code holdsShow} 와 같은 규칙. */
    ALREADY_RESERVED(HttpStatus.CONFLICT, "이미 이 공연의 티켓을 보유하고 있습니다."),
    /** "예매 오픈 시각 이전에는 좌석 선택이 성립되지 않는다." 온체인 {@code SaleNotOpen} 과 같은 규칙. */
    CONCERT_NOT_ON_SALE(HttpStatus.CONFLICT, "예매 중인 공연이 아닙니다."),
    /**
     * 취소할 수 없는 주문. 발행 전·이미 끝난 주문, 양도 등록 중({@code LISTED})·입장 완료({@code USED}) 티켓,
     * 공연 시작 24시간 이내. 온체인 {@code revoke} 는 {@code OWNED} 에서만 성립한다.
     */
    RESERVATION_NOT_CANCELLABLE(HttpStatus.CONFLICT, "취소할 수 없는 주문입니다.");

    private final HttpStatus status;
    private final String message;
}
