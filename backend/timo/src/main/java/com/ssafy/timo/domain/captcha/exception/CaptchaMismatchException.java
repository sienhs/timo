package com.ssafy.timo.domain.captcha.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 입력값이 캡차 이미지와 다른 경우.
 *
 * <p>사용자가 무엇을 입력했는지는 메시지에 담지 않는다. 응답과 로그에 그대로 남으면 캡차 정답 후보가
 * 쌓이는 셈이다.
 */
public class CaptchaMismatchException extends BusinessException {

    public CaptchaMismatchException() {
        super(CaptchaErrorCode.CAPTCHA_MISMATCH);
    }
}
