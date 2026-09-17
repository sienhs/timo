package com.ssafy.timo.domain.ticket.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

/**
 * 게이트 검표 결과.
 *
 * <p><b>거절도 4xx 가 아니라 200 이다.</b> "들여보낼 수 없다" 는 정상적인 판정 결과이지 요청이
 * 잘못된 것이 아니다. 게이트 앱이 상태 코드를 해석하지 않고 {@code admitted} 만 보게 하려는 것이고
 * ({@code gate/README.md} 규약), 덕분에 앱은 4xx/5xx 를 전부 "판정 실패(네트워크·서버 문제)" 하나로
 * 다룰 수 있다.
 *
 * <p>좌석·예매자 정보는 싣지 않는다(팀 결정). 게이트는 들여보낼지만 판단하면 되고, 관람객 정보를
 * 단말 화면에 띄우는 것은 개인정보만 늘린다.
 *
 * @param admitted   입장 허용 여부
 * @param reasonCode 거절 사유. 허용이면 응답에 아예 나타나지 않는다
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record GateEntryVerifyResponseDto(boolean admitted, GateRejectReason reasonCode) {

    public static GateEntryVerifyResponseDto admit() {
        return new GateEntryVerifyResponseDto(true, null);
    }

    public static GateEntryVerifyResponseDto reject(GateRejectReason reasonCode) {
        return new GateEntryVerifyResponseDto(false, reasonCode);
    }
}
