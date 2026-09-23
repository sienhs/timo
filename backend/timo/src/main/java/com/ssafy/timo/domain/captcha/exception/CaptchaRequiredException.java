package com.ssafy.timo.domain.captcha.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 보호된 API 를 캡차 통과 기록 없이 호출한 경우.
 *
 * <p>통과 기록이 아예 없는 것과 유효 시간이 지난 것을 가르지 않는다. 앱이 할 일은 어느 쪽이든
 * 캡차 화면을 다시 띄우는 것 하나다.
 */
public class CaptchaRequiredException extends BusinessException {

    public CaptchaRequiredException() {
        super(CaptchaErrorCode.CAPTCHA_REQUIRED);
    }
}
