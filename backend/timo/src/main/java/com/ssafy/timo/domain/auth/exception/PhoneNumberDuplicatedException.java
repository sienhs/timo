package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class PhoneNumberDuplicatedException extends BusinessException {

    public PhoneNumberDuplicatedException() {
        super(SignupErrorCode.PHONE_NUMBER_DUPLICATED);
    }
}
