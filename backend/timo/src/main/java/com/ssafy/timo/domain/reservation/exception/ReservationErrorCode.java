package com.ssafy.timo.domain.reservation.exception;

import com.ssafy.timo.domain.concert.entity.Concert;
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
    /** 상태가 예매 중(ON_SALE)이 아니다 - 등록만 된 공연, 매진, 종료, 취소. 오픈 전·마감 후는 아래 두 코드다. */
    CONCERT_NOT_ON_SALE(HttpStatus.CONFLICT, "예매 중인 공연이 아닙니다."),
    /** 공연은 예매 중(ON_SALE)이지만 아직 오픈 시각 전이다. */
    BOOKING_NOT_OPEN(HttpStatus.CONFLICT, "아직 예매가 열리지 않았습니다."),
    /**
     * 공연 시작 {@value com.ssafy.timo.domain.concert.entity.Concert#BOOKING_CUTOFF_HOURS}시간 전, 예매 마감을 지났다.
     *
     * <p>문구에 시간을 <b>박아 두지 않고</b> {@link Concert#BOOKING_CUTOFF_HOURS} 에서 만든다.
     * 마감을 몇 시간 전으로 할지는 한 곳에서만 정해져야 하는데, 안내 문구를 따로 적어 두면 상수를
     * 바꾼 날 서버는 새 규칙으로 막으면서 사용자에게는 옛 규칙을 알려주게 된다.
     */
    BOOKING_CLOSED(HttpStatus.CONFLICT,
            "예매가 마감되었습니다. (공연 시작 " + Concert.BOOKING_CUTOFF_HOURS + "시간 전 마감)"),
    /**
     * 취소할 수 없는 주문. 발행 전·이미 끝난 주문, 양도 등록 중({@code LISTED})·입장 완료({@code USED}) 티켓,
     * 공연 시작 24시간 이내. 온체인 {@code revoke} 는 {@code OWNED} 에서만 성립한다.
     */
    RESERVATION_NOT_CANCELLABLE(HttpStatus.CONFLICT, "취소할 수 없는 주문입니다.");

    private final HttpStatus status;
    private final String message;
}
