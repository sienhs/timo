package com.ssafy.timo.domain.captcha.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 네이버 캡차 API 호출이 실패한 경우.
 *
 * <p>원인을 {@code cause} 로 달고 다닌다. {@code BusinessException} 의 생성자가 원인을 받지 않아
 * {@link #initCause} 로 붙인다 - {@code RuntimeException(String)} 은 원인을 미설정 상태로 두므로
 * 나중에 한 번 붙일 수 있다.
 *
 * <p><b>이 예외를 던지는 쪽이 직접 로그를 남겨야 한다.</b> {@code GlobalExceptionHandler} 는
 * 비즈니스 예외를 의도된 것으로 보고 스택트레이스 없이 warn 한 줄만 남기므로, 여기 달아 둔 원인은
 * 그대로는 어디에도 찍히지 않는다.
 */
public class CaptchaProviderException extends BusinessException {

    public CaptchaProviderException(Throwable cause) {
        super(CaptchaErrorCode.CAPTCHA_PROVIDER_ERROR);
        initCause(cause);
    }

    /**
     * 원인이 확실하고 곧 풀리는 하위 유형({@link CaptchaConcurrencyLimitExceededException})만 쓴다.
     * 원인이 불확실한 일반 실패(위 생성자)에는 재시도 시간을 주지 않는다.
     */
    protected CaptchaProviderException(long retryAfterSeconds) {
        super(CaptchaErrorCode.CAPTCHA_PROVIDER_ERROR, CaptchaErrorCode.CAPTCHA_PROVIDER_ERROR.getMessage(),
                retryAfterSeconds);
    }
}
