package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class NicknameDuplicatedException extends BusinessException {

    public NicknameDuplicatedException() {
        super(SignupErrorCode.NICKNAME_DUPLICATED);
    }
}
