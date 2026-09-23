package com.ssafy.timo.domain.captcha.exception;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.global.exception.BusinessException;
import java.io.IOException;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;
import org.springframework.http.HttpStatus;

/**
 * 캡차 예외가 {@code GlobalExceptionHandler} 를 타고 공통 포맷으로 나가는지 본다.
 *
 * <p>핸들러를 실제로 태우는 검증은 {@code GlobalExceptionHandlerTest} 가 프로브 컨트롤러로 이미
 * 하고 있다({@code /test/business-exception/domain}). 그쪽이 보는 것은 "도메인 에러 코드를 담은
 * {@code BusinessException} 이면 그 상태로 나간다" 는 규칙이라, 여기서는 캡차 예외들이 그 규칙의
 * 입력 조건을 만족하는지 - 즉 {@code BusinessException} 을 상속하고 제 코드를 달고 있는지만 본다.
 */
class CaptchaErrorCodeTest {

    static Stream<Arguments> exceptions() {
        return Stream.of(
                Arguments.of(new CaptchaMismatchException(), CaptchaErrorCode.CAPTCHA_MISMATCH),
                Arguments.of(new CaptchaKeyOwnerMismatchException(), CaptchaErrorCode.CAPTCHA_KEY_OWNER_MISMATCH),
                Arguments.of(new CaptchaKeyNotFoundException(), CaptchaErrorCode.CAPTCHA_KEY_NOT_FOUND),
                Arguments.of(new CaptchaRequiredException(), CaptchaErrorCode.CAPTCHA_REQUIRED),
                Arguments.of(new CaptchaTooManyRequestsException(), CaptchaErrorCode.CAPTCHA_TOO_MANY_REQUESTS),
                Arguments.of(new CaptchaProviderException(new IOException("boom")),
                        CaptchaErrorCode.CAPTCHA_PROVIDER_ERROR),
                Arguments.of(new CaptchaConcurrencyLimitExceededException(),
                        CaptchaErrorCode.CAPTCHA_PROVIDER_ERROR));
    }

    @ParameterizedTest(name = "{1}")
    @MethodSource("exceptions")
    @DisplayName("캡차 예외는 BusinessException 을 상속하고 제 에러 코드와 메시지를 단다")
    void carriesOwnErrorCode(BusinessException exception, CaptchaErrorCode expected) {
        assertThat(exception).isInstanceOf(BusinessException.class);
        assertThat(exception.getErrorCode()).isEqualTo(expected);
        assertThat(exception.getMessage()).isEqualTo(expected.getMessage());
    }

    @Test
    @DisplayName("상태 코드는 정해진 표와 같다")
    void mapsToDecidedStatuses() {
        assertThat(CaptchaErrorCode.CAPTCHA_MISMATCH.getStatus()).isEqualTo(HttpStatus.BAD_REQUEST);
        assertThat(CaptchaErrorCode.CAPTCHA_KEY_OWNER_MISMATCH.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(CaptchaErrorCode.CAPTCHA_KEY_NOT_FOUND.getStatus()).isEqualTo(HttpStatus.NOT_FOUND);
        assertThat(CaptchaErrorCode.CAPTCHA_REQUIRED.getStatus()).isEqualTo(HttpStatus.FORBIDDEN);
        assertThat(CaptchaErrorCode.CAPTCHA_TOO_MANY_REQUESTS.getStatus()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
        assertThat(CaptchaErrorCode.CAPTCHA_PROVIDER_ERROR.getStatus()).isEqualTo(HttpStatus.BAD_GATEWAY);
    }

    @Test
    @DisplayName("공급자 실패는 원인을 달고 다닌다 - 던지는 쪽이 그걸 로그로 남길 수 있어야 한다")
    void providerExceptionKeepsCause() {
        IOException cause = new IOException("connect timed out");

        assertThat(new CaptchaProviderException(cause)).hasCause(cause);
    }

    @Test
    @DisplayName("동시 호출 상한 초과는 재시도 대기 시간을 달고 다닌다 - GlobalExceptionHandler 가 " +
            "Retry-After 헤더로 그대로 내보낸다")
    void concurrencyLimitExceededCarriesRetryAfter() {
        assertThat(new CaptchaConcurrencyLimitExceededException().getRetryAfterSeconds())
                .isEqualTo(CaptchaConcurrencyLimitExceededException.RETRY_AFTER_SECONDS);
    }

}
