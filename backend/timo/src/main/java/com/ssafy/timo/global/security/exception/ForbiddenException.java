package com.ssafy.timo.global.security.exception;

public class ForbiddenException extends AuthException {

    public ForbiddenException() {
        super(AuthErrorCode.FORBIDDEN);
    }
}
