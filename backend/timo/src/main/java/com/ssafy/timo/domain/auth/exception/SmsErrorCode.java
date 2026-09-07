package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum SmsErrorCode implements BaseErrorCode {

    SMS_SEND_LIMIT_EXCEEDED(HttpStatus.TOO_MANY_REQUESTS, "인증 문자 발송 횟수를 초과했습니다. 잠시 후 다시 시도해 주세요."),
    SMS_CODE_NOT_FOUND(HttpStatus.BAD_REQUEST, "인증 코드가 만료되었습니다. 다시 요청해 주세요."),
    SMS_CODE_MISMATCH(HttpStatus.BAD_REQUEST, "인증 코드가 올바르지 않습니다."),
    SMS_ATTEMPT_EXCEEDED(HttpStatus.TOO_MANY_REQUESTS, "인증 시도 횟수를 초과했습니다. 다시 요청해 주세요."),
    SMS_SEND_FAILED(HttpStatus.BAD_GATEWAY, "인증 문자 발송에 실패했습니다. 잠시 후 다시 시도해 주세요.");

    private final HttpStatus status;
    private final String message;
}
