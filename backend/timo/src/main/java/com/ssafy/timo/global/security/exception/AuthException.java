package com.ssafy.timo.global.security.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 인증·인가 실패를 나타내는 예외의 공통 상위 타입.
 *
 * <p>{@link BusinessException} 을 그대로 써도 응답은 나가지만, 그러면
 * {@code AuthExceptionHandler} 가 "이건 인증 실패다" 라고 골라낼 방법이 없다.
 * 인증 응답에만 {@code errorCode} 를 싣기 위해 타입을 하나 둔다.
 *
 * <p>에러 코드는 {@link AuthErrorCode} 로 고정한다. 인증 실패에 다른 도메인의 코드가
 * 섞이면 앱의 분기 규칙이 무너진다.
 */
public abstract class AuthException extends BusinessException {

    protected AuthException(AuthErrorCode errorCode) {
        super(errorCode);
    }

    @Override
    public AuthErrorCode getErrorCode() {
        return (AuthErrorCode) super.getErrorCode();
    }
}
