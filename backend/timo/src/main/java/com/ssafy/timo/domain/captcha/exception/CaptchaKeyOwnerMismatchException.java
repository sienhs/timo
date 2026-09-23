package com.ssafy.timo.domain.captcha.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 남에게 발급된 캡차 키로 검증을 시도한 경우.
 *
 * <p>누구의 키인지는 메시지에 담지 않는다. 응답으로 나가면 키를 바꿔 가며 다른 사용자의 발급 여부를
 * 떠볼 수 있다.
 */
public class CaptchaKeyOwnerMismatchException extends BusinessException {

    public CaptchaKeyOwnerMismatchException() {
        super(CaptchaErrorCode.CAPTCHA_KEY_OWNER_MISMATCH);
    }
}
