package com.ssafy.timo.global.security.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class ForbiddenException extends BusinessException {

    public ForbiddenException() {
        super(AuthErrorCode.FORBIDDEN);
    }
}
