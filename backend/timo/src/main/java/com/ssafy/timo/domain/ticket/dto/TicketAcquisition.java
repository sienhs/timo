package com.ssafy.timo.domain.ticket.dto;

/**
 * 이 티켓이 내 것이 된 경로. 화면이 예매 취소 버튼을 보여줄지 가를 때 쓴다.
 *
 * <p><b>{@link #TRANSFER} 인 티켓은 예매 취소를 걸 수 없다</b> — 예매 행이 판 사람 것이라 요청해도
 * 404 가 난다. 서버가 알려주지 않으면 앱은 눌러 보고 나서야 알게 된다.
 */
public enum TicketAcquisition {

    /** 직접 예매 */
    BOOKING,

    /** 양도 마켓 거래 */
    TRANSFER
}
