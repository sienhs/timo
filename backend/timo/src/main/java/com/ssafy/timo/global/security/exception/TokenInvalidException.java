package com.ssafy.timo.global.security.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class TokenInvalidException extends BusinessException {

    public TokenInvalidException() {
        super(AuthErrorCode.TOKEN_INVALID);
    }
}
