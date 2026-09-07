package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class SmsCodeNotFoundException extends BusinessException {

    public SmsCodeNotFoundException() {
        super(SmsErrorCode.SMS_CODE_NOT_FOUND);
    }
}
