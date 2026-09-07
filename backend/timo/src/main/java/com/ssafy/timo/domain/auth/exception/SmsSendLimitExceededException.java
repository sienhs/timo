package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class SmsSendLimitExceededException extends BusinessException {

    public SmsSendLimitExceededException() {
        super(SmsErrorCode.SMS_SEND_LIMIT_EXCEEDED);
    }
}
