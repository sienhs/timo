package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class SmsAttemptExceededException extends BusinessException {

    public SmsAttemptExceededException() {
        super(SmsErrorCode.SMS_ATTEMPT_EXCEEDED);
    }
}
