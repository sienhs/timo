package com.ssafy.timo.global.security.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class TokenExpiredException extends BusinessException {

    public TokenExpiredException() {
        super(AuthErrorCode.TOKEN_EXPIRED);
    }
}
