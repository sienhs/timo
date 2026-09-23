package com.ssafy.timo.domain.captcha.client;

import com.ssafy.timo.domain.captcha.exception.CaptchaProviderException;

/**
 * 캡차 공급자 호출 규약.
 *
 * <p>구현이 둘이다 - 실제로 네이버를 부르는 {@link NaverCaptchaClient} 와, 로컬·테스트에서 뜨는
 * {@link StubCaptchaClient}. 인터페이스를 둔 이유는 통합 테스트 때문이다. 공용 컨텍스트
 * ({@code com.ssafy.timo.support.IntegrationTest})가 {@code @MockitoBean} 을 금지하므로, 발급·검증
 * 흐름을 끝까지 태우려면 프로파일로 갈리는 구현이 필요하다. {@code SmsSender} 와 같은 구조다.
 */
public interface CaptchaClient {

    /**
     * 캡차 키를 발급받는다. 이 키로 이미지를 받고, 나중에 같은 키로 검증한다.
     *
     * @throws CaptchaProviderException 공급자 호출이 실패했거나 응답에 키가 없으면
     */
    String issueKey();

    /**
     * 키에 해당하는 캡차 이미지를 받는다.
     *
     * @throws CaptchaProviderException 공급자 호출이 실패했거나 본문이 비어 있으면
     */
    byte[] fetchImage(String key);

    /**
     * 입력값이 캡차와 맞는지 묻는다. <b>오답은 예외가 아니라 {@code false} 다</b> - 502 로 만들면
     * 앱이 다시 입력하라고 안내할 수 없다.
     *
     * @throws CaptchaProviderException 공급자 호출이 실패했거나 응답에 결과가 없으면
     */
    boolean verify(String key, String value);
}
