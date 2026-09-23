package com.ssafy.timo.domain.captcha.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 1분 안에 캡차를 허용 횟수보다 많이 발급받으려 한 경우. */
public class CaptchaTooManyRequestsException extends BusinessException {

    public CaptchaTooManyRequestsException() {
        super(CaptchaErrorCode.CAPTCHA_TOO_MANY_REQUESTS);
    }
}
