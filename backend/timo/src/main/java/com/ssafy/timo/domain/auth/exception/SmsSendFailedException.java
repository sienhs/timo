package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class SmsSendFailedException extends BusinessException {

    public SmsSendFailedException() {
        super(SmsErrorCode.SMS_SEND_FAILED);
    }
}
