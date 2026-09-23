package com.ssafy.timo.domain.captcha.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 캡차 키가 없거나, 만료됐거나, 이미 한 번 쓰인 경우.
 *
 * <p>셋을 가르지 않는다. 우리 쪽에서도 저장소에 값이 없다는 사실만 알 수 있고, 굳이 갈라 주면
 * "그 키는 존재했다"를 알려 주는 셈이다.
 */
public class CaptchaKeyNotFoundException extends BusinessException {

    public CaptchaKeyNotFoundException() {
        super(CaptchaErrorCode.CAPTCHA_KEY_NOT_FOUND);
    }
}
