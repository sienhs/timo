package com.ssafy.timo.domain.auth.dto;

public record SmsVerifyResponseDto(
        String verificationTicket,
        int expiresInSeconds
) {
}
