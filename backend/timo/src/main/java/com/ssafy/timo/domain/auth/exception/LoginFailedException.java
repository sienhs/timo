package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.security.exception.AuthErrorCode;
import com.ssafy.timo.global.security.exception.AuthException;

/**
 * 아이디가 없거나 비밀번호가 틀렸을 때. <b>둘을 구분하지 않는다.</b>
 *
 * <p>{@code AuthException} 을 상속하는 이유는 응답에 {@code errorCode} 를 실기 위해서다.
 * 일반 {@code BusinessException} 으로 두면 {@code GlobalExceptionHandler} 가 처리해
 * {@code errorCode} 가 빠지고, 앱은 이 400 을 입력 형식 오류와 구분할 수 없게 된다.
 */
public class LoginFailedException extends AuthException {

    public LoginFailedException() {
        super(AuthErrorCode.LOGIN_FAILED);
    }
}
