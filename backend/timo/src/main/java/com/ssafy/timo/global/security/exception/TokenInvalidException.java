package com.ssafy.timo.global.security.exception;

public class TokenInvalidException extends AuthException {

    public TokenInvalidException() {
        super(AuthErrorCode.TOKEN_INVALID);
    }
}
