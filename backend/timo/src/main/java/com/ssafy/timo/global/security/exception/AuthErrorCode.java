package com.ssafy.timo.global.security.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum AuthErrorCode implements BaseErrorCode {

    TOKEN_EXPIRED(HttpStatus.UNAUTHORIZED, "인증이 만료되었습니다."),
    TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "인증 정보가 올바르지 않습니다. 다시 로그인해 주세요."),
    REFRESH_REUSED(HttpStatus.UNAUTHORIZED, "보안을 위해 로그아웃되었습니다. 다시 로그인해 주세요."),
    FORBIDDEN(HttpStatus.FORBIDDEN, "접근 권한이 없습니다.");

    private final HttpStatus status;
    private final String message;
}
