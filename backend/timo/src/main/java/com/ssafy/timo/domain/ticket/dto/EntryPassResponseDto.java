package com.ssafy.timo.domain.ticket.dto;

import com.ssafy.timo.domain.ticket.service.EntryPassProvider.EntryPass;

/**
 * 입장 QR 발급 응답.
 *
 * <p>{@code token} 은 앱이 <b>해석하지 않고</b> 그대로 QR 로 그리는 문자열이다. 앱이 안을 들여다보기
 * 시작하면 형식을 바꿀 때마다 앱 배포까지 묶인다. 남은 시간도 토큰에서 뽑지 말고
 * {@code expiresInSeconds} 를 쓰라고 따로 내려주는 이유가 그것이다.
 *
 * <p>좌석·공연 정보는 싣지 않는다. QR 화면은 이미 티켓 상세에서 들어오므로 화면이 다 알고 있고,
 * 발급 응답에 개인정보를 더 얹을 이유가 없다.
 *
 * @param token            QR 에 그대로 실릴 문자열
 * @param expiresInSeconds 남은 수명(초). 앱은 이 값이 다하기 전에 미리 다시 받아 간다
 */
public record EntryPassResponseDto(String token, long expiresInSeconds) {

    public static EntryPassResponseDto from(EntryPass entryPass) {
        return new EntryPassResponseDto(entryPass.value(), entryPass.expiresInSeconds());
    }
}
