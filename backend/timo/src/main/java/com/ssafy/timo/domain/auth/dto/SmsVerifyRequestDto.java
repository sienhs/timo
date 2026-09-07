package com.ssafy.timo.domain.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record SmsVerifyRequestDto(

        @NotBlank(message = "휴대폰 번호는 필수입니다.")
        @Pattern(regexp = "^01[016789][0-9]{7,8}$", message = "휴대폰 번호 형식이 올바르지 않습니다.")
        String phoneNumber,

        @NotBlank(message = "인증 코드는 필수입니다.")
        @Pattern(regexp = "^[0-9]{6}$", message = "인증 코드는 6자리 숫자입니다.")
        String code
) {
}
