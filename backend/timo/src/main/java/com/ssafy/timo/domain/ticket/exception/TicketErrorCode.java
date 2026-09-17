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

    /** 발행 전(PENDING_MINT)·실패(MINT_FAILED)·이미 입장(USED)·회수(REVOKED)·환불(REFUNDED)·양도 등록 중(LISTED). */
    TICKET_STATUS_NOT_ISSUABLE(HttpStatus.CONFLICT, "입장 QR 을 발급할 수 없는 티켓입니다."),

    /** 공연 시작 전, 아직 발급 창이 열리지 않았다. */
    ENTRY_WINDOW_NOT_OPEN(HttpStatus.CONFLICT, "아직 입장 QR 을 받을 수 없습니다."),

    /** 공연 시작 뒤, 발급 창이 닫혔다. */
    ENTRY_WINDOW_CLOSED(HttpStatus.CONFLICT, "입장 QR 발급 시간이 지났습니다.");

    private final HttpStatus status;
    private final String message;
}
