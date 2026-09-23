package com.ssafy.timo.domain.captcha.exception;

/**
 * 네이버로 나가는 동시 호출 상한({@code naver.captcha.max-concurrent-calls})을 넘어 거절된 경우.
 *
 * <p>{@link CaptchaProviderException} 과 같은 502 지만 성격이 다르다 - 네이버가 실패를 준 게
 * 아니라 <b>우리 쪽이 부르지도 않고 거절</b>한 것이고, 원인(자리 없음)이 확실하며 자리는 곧
 * 풀린다(요청 하나가 오래 걸려야 read timeout 3초). 그래서 {@code GlobalExceptionHandler} 가 이
 * 예외에는 {@code Retry-After} 헤더를 함께 내려준다 - 클라이언트가 재시도 간격을 추측하지 않게.
 *
 * <p>재시도를 곧바로/무한정 하면 안 된다. {@code CaptchaService.issue()} 는 발급 한도(분당 10회)를
 * 이 호출보다 먼저 검사하고, <b>거절된 시도도 그 한도를 깎는다</b>(B6) - 재시도를 촘촘히 반복하면
 * 이 502 때문에 진짜 발급 한도(429)까지 넘겨 버릴 수 있다.
 */
public class CaptchaConcurrencyLimitExceededException extends CaptchaProviderException {

    /**
     * 클라이언트에게 권고하는 재시도 대기 시간(초). 세마포어 자리가 정확히 이 시간 뒤에 빈다는
     * 보장은 아니고, "곧 빈다"는 정도의 값이다 - 정확한 값은 부하테스트 전까지 알 수 없다.
     */
    public static final long RETRY_AFTER_SECONDS = 1;

    public CaptchaConcurrencyLimitExceededException() {
        super(RETRY_AFTER_SECONDS);
    }
}
