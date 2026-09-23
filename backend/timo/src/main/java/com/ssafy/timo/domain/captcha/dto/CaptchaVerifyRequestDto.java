package com.ssafy.timo.domain.captcha.dto;

import com.ssafy.timo.global.util.Masked;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 캡차 검증 요청.
 *
 * <p>{@code concertId} 는 회차 대신 쓰는 값이다. 이 코드베이스에 회차 도메인이 없어 캡차 통과
 * 단위를 공연으로 잡았다({@code docs/BE_CAPTCHA_TASK_BREAKDOWN.md} 0-1 참고).
 *
 * @param concertId  통과 기록을 남길 공연. 존재해야 한다
 * @param captchaKey 발급받은 캡차 키. 검증 성공·실패와 무관하게 이 요청으로 폐기된다
 * @param value      사용자가 입력한 캡차 값
 */
public record CaptchaVerifyRequestDto(

        @NotNull(message = "concertId는 필수입니다.")
        Long concertId,

        @NotBlank(message = "captchaKey는 필수입니다.")
        String captchaKey,

        @NotBlank(message = "value는 필수입니다.")
        @Size(max = 20, message = "value는 20자를 넘을 수 없습니다.")
        String value
) {

    // value 는 캡차 정답 후보다. 로그에 그대로 남으면 캡차를 두는 의미가 없어진다.
    @Override
    public String toString() {
        return "CaptchaVerifyRequestDto[concertId=%d, captchaKey=%s, value=%s]"
                .formatted(concertId, captchaKey, Masked.of(value));
    }
}
