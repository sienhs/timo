package com.ssafy.timo.domain.auth.dto;

import com.ssafy.timo.global.util.Masked;
public record SmsVerifyResponseDto(
        String verificationTicket,
        int expiresInSeconds
) {

    @Override
    public String toString() {
        return "SmsVerifyResponseDto[verificationTicket=%s, expiresInSeconds=%d]"
                .formatted(Masked.of(verificationTicket), expiresInSeconds);
    }
}
