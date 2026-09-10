package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/**
 * 양도 마켓 에러 코드.
 *
 * <p>{@code TICKET_NOT_FOUND}·{@code NOT_TICKET_OWNER}·{@code TICKET_NOT_LISTABLE} 은 원래 티켓 도메인의
 * 것이다. 티켓 도메인이 아직 없어 여기 두었다. <b>TODO</b>: 티켓 도메인이 생기면 그쪽으로 옮긴다.
 *
 * <p>"이미 이 공연의 티켓을 보유하고 있습니다"(1인 1매)는 예매와 같은 규칙이라 예매 도메인의
 * {@code AlreadyReservedException} 을 그대로 쓴다. 같은 규칙이 두 코드로 갈리면 앱이 분기를 두 번 짜야 한다.
 */
@Getter
@RequiredArgsConstructor
public enum TransferErrorCode implements BaseErrorCode {

    TICKET_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 티켓입니다."),
    /** 온체인 {@code NotTicketOwner}. */
    NOT_TICKET_OWNER(HttpStatus.FORBIDDEN, "본인이 보유한 티켓이 아닙니다."),
    /** 온체인 {@code UnexpectedStatus(required=OWNED)}. 이미 등록 중이거나 입장·회수된 티켓. */
    TICKET_NOT_LISTABLE(HttpStatus.CONFLICT, "양도 등록할 수 있는 상태의 티켓이 아닙니다."),
    /** 온체인 {@code ListPriceExceedsFacePrice}. "등록가가 정가 이하일 때에만 등록이 성립한다." */
    LIST_PRICE_EXCEEDS_FACE_PRICE(HttpStatus.BAD_REQUEST, "등록가는 정가를 초과할 수 없습니다."),
    LISTING_NOT_FOUND(HttpStatus.NOT_FOUND, "등록된 양도 매물이 아닙니다."),
    CANNOT_BUY_OWN_LISTING(HttpStatus.CONFLICT, "본인이 등록한 매물은 구매할 수 없습니다.");

    private final HttpStatus status;
    private final String message;
}
