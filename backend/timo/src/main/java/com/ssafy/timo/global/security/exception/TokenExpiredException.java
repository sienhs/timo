package com.ssafy.timo.global.security.exception;

public class TokenExpiredException extends AuthException {

    public TokenExpiredException() {
        super(AuthErrorCode.TOKEN_EXPIRED);
    }
}
