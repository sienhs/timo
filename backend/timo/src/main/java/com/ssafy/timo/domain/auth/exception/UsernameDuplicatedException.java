package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class UsernameDuplicatedException extends BusinessException {

    public UsernameDuplicatedException() {
        super(SignupErrorCode.USERNAME_DUPLICATED);
    }
}
