package com.ssafy.timo.domain.ticket.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum TicketErrorCode implements BaseErrorCode {

    /** 남의 티켓도 이 코드로 답한다 - 존재 여부 자체가 정보라, 주문 조회와 같은 규칙을 쓴다. */
    TICKET_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 티켓입니다."),
    /** 발행 전·이미 입장·회수된 티켓이거나, 입장 시간대가 아닌 경우. */
    ENTRY_PASS_NOT_ISSUABLE(HttpStatus.CONFLICT, "입장 QR 을 발급할 수 없는 티켓입니다.");

    private final HttpStatus status;
    private final String message;
}
