package com.ssafy.timo.domain.ticket.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

/**
 * 게이트 검표 요청.
 *
 * <p>{@code qr} 은 카메라가 읽은 문자열 <b>그대로</b>다. 게이트 앱은 내용을 해석하지 않는다 -
 * 앱이 파싱하기 시작하면 토큰 형식을 바꿀 때마다 게이트 APK 재배포까지 묶인다.
 *
 * <p>{@code concertId} 를 함께 받는 이유: 이 단말이 어느 공연의 입구에 서 있는지는 QR 이 알려줄 수
 * 없다. 옆 공연 티켓을 들고 온 관람객을 가려내려면 게이트가 자기 공연을 말해 줘야 한다.
 *
 * @param qr        QR 에서 읽은 문자열 원문
 * @param concertId 이 게이트가 검표 중인 공연
 */
public record GateEntryVerifyRequestDto(

        @NotBlank(message = "QR 값은 필수입니다.")
        String qr,

        @NotNull(message = "공연 ID는 필수입니다.")
        Long concertId
) {
}
