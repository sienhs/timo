package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class SmsCodeMismatchException extends BusinessException {

    public SmsCodeMismatchException() {
        super(SmsErrorCode.SMS_CODE_MISMATCH);
    }
}
