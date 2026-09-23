package com.ssafy.timo.domain.captcha.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.header;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withException;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withServerError;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

import com.ssafy.timo.domain.captcha.exception.CaptchaConcurrencyLimitExceededException;
import com.ssafy.timo.domain.captcha.exception.CaptchaProviderException;
import com.ssafy.timo.global.config.captcha.NaverCaptchaProperties;
import java.io.IOException;
import java.net.SocketTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

/** 네이버 응답을 그대로 흉내 내, 우리 쪽 변환과 실패 처리만 본다. */
class NaverCaptchaClientTest {

    private static final String BASE_URL = "https://openapi.naver.com";
    private static final String CLIENT_ID = "test-client-id";
    private static final String CLIENT_SECRET = "test-client-secret";

    private MockRestServiceServer server;
    private NaverCaptchaClient client;

    @BeforeEach
    void setUp() {
        RestClient.Builder builder = mockRestClientBuilder();
        server = MockRestServiceServer.bindTo(builder).build();
        client = new NaverCaptchaClient(properties(), builder.build());
    }

    /**
     * 실제 생성자({@code NaverCaptchaClient(NaverCaptchaProperties)})가 등록하는 것과 같은
     * 컨버터를 쓴다. 여기서 빠뜨리면 {@code application/octet-stream} 관련 테스트가 프로덕션과
     * 다른 설정으로 통과해 버려, 실제로는 안 고쳐진 문제를 고쳐졌다고 오판할 수 있다.
     */
    private static RestClient.Builder mockRestClientBuilder() {
        return RestClient.builder().baseUrl(BASE_URL)
                .messageConverters(converters -> converters.add(NaverCaptchaClient.jsonConverter()));
    }

    @Test
    @DisplayName("키 발급은 응답의 key 를 그대로 돌려준다")
    void issueKeyReturnsKey() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0"))
                .andExpect(method(HttpMethod.GET))
                .andRespond(withSuccess("{\"key\":\"abc123\"}", MediaType.APPLICATION_JSON));

        assertThat(client.issueKey()).isEqualTo("abc123");
        server.verify();
    }

    @Test
    @DisplayName("모든 요청에 네이버 인증 헤더가 붙는다")
    void sendsCredentialHeaders() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0"))
                .andExpect(header("X-Naver-Client-Id", CLIENT_ID))
                .andExpect(header("X-Naver-Client-Secret", CLIENT_SECRET))
                .andRespond(withSuccess("{\"key\":\"abc123\"}", MediaType.APPLICATION_JSON));

        client.issueKey();
        server.verify();
    }

    @Test
    @DisplayName("이미지 조회는 본문을 byte[] 로 돌려준다")
    void fetchImageReturnsBytes() {
        byte[] image = "fake-jpeg".getBytes(StandardCharsets.UTF_8);
        server.expect(requestTo(BASE_URL + "/v1/captcha/ncaptcha.bin?key=abc123"))
                .andRespond(withSuccess(image, MediaType.IMAGE_JPEG));

        assertThat(client.fetchImage("abc123")).isEqualTo(image);
        server.verify();
    }

    @Test
    @DisplayName("검증 결과 true 가 그대로 나온다")
    void verifyReturnsTrue() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=1&key=abc123&value=hello"))
                .andRespond(withSuccess("{\"result\":true}", MediaType.APPLICATION_JSON));

        assertThat(client.verify("abc123", "hello")).isTrue();
        server.verify();
    }

    @Test
    @DisplayName("오답은 실패가 아니라 false 다 - 502 로 만들면 앱이 재입력을 안내할 수 없다")
    void verifyReturnsFalse() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=1&key=abc123&value=wrong"))
                .andRespond(withSuccess("{\"result\":false}", MediaType.APPLICATION_JSON));

        assertThat(client.verify("abc123", "wrong")).isFalse();
    }

    @Test
    @DisplayName("입력값의 쿼리 구분자는 인코딩돼 나간다 - 잘린 값으로 검증되면 안 된다")
    void encodesUserInput() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=1&key=abc123&value=a%26b%3Dc"))
                .andRespond(withSuccess("{\"result\":false}", MediaType.APPLICATION_JSON));

        client.verify("abc123", "a&b=c");
        server.verify();
    }

    @Test
    @DisplayName("5xx 는 CAPTCHA_PROVIDER_ERROR 로 바뀐다")
    void serverErrorBecomesProviderError() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0")).andRespond(withServerError());

        assertThatThrownBy(() -> client.issueKey()).isInstanceOf(CaptchaProviderException.class);
    }

    @Test
    @DisplayName("타임아웃도 CAPTCHA_PROVIDER_ERROR 로 바뀐다")
    void timeoutBecomesProviderError() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0"))
                .andRespond(withException(new SocketTimeoutException("read timed out")));

        assertThatThrownBy(() -> client.issueKey()).isInstanceOf(CaptchaProviderException.class);
    }

    @Test
    @DisplayName("200 이어도 응답에 key 가 없으면 CAPTCHA_PROVIDER_ERROR 다")
    void missingKeyBecomesProviderError() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0"))
                .andRespond(withSuccess("{}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.issueKey()).isInstanceOf(CaptchaProviderException.class);
    }

    @Test
    @DisplayName("검증 응답에 result 가 없으면 CAPTCHA_PROVIDER_ERROR 다 - 조용히 false 로 읽지 않는다")
    void missingResultBecomesProviderError() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=1&key=abc123&value=hello"))
                .andRespond(withSuccess("{}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(() -> client.verify("abc123", "hello"))
                .isInstanceOf(CaptchaProviderException.class);
    }

    @Test
    @DisplayName("네이버가 Content-Type 을 application/octet-stream 으로 보내도 JSON 으로 읽는다 - " +
            "실제 nkey 응답이 Content-Type 자체를 안 보내 커넥션 팩토리가 이 값으로 채운다(2026-09-24 실측)")
    void readsJsonBodyDespiteOctetStreamContentType() {
        server.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0"))
                .andRespond(withSuccess("{\"key\":\"abc123\"}", MediaType.APPLICATION_OCTET_STREAM));

        assertThat(client.issueKey()).isEqualTo("abc123");
        server.verify();
    }

    @Test
    @DisplayName("Content-Type 이 어긋나도 이미지 조회(byte[])는 여전히 byte[] 컨버터가 받는다")
    void imageFetchStillWorksAlongsideTheOctetStreamJsonFallback() {
        byte[] image = "fake-jpeg".getBytes(StandardCharsets.UTF_8);
        server.expect(requestTo(BASE_URL + "/v1/captcha/ncaptcha.bin?key=abc123"))
                .andRespond(withSuccess(image, MediaType.APPLICATION_OCTET_STREAM));

        assertThat(client.fetchImage("abc123")).isEqualTo(image);
        server.verify();
    }

    // ---------------------------------------------------------------- 동시 호출 상한

    @Test
    @DisplayName("한도(1)를 쥔 동안 들어온 두 번째 호출은 기다리지 않고 즉시 502 다")
    void rejectsConcurrentCallBeyondLimit() throws Exception {
        RestClient.Builder builder = mockRestClientBuilder();
        MockRestServiceServer limitedServer = MockRestServiceServer.bindTo(builder).build();
        NaverCaptchaClient limitedClient = new NaverCaptchaClient(propertiesWithLimit(1), builder.build());

        CountDownLatch started = new CountDownLatch(1);
        CountDownLatch release = new CountDownLatch(1);

        // 첫 호출이 응답을 받기 전까지 자리를 계속 쥐고 있게, 응답을 고의로 묶어 둔다.
        limitedServer.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0"))
                .andRespond(request -> {
                    started.countDown();
                    try {
                        release.await();
                    } catch (InterruptedException e) {
                        Thread.currentThread().interrupt();
                        throw new IOException(e);
                    }
                    return withSuccess("{\"key\":\"abc123\"}", MediaType.APPLICATION_JSON).createResponse(request);
                });

        Thread firstCall = new Thread(limitedClient::issueKey);
        firstCall.start();
        assertThat(started.await(2, TimeUnit.SECONDS)).isTrue();

        try {
            // 첫 호출이 아직 응답을 못 받아 자리를 쥔 채다 - 두 번째는 네이버에 닿지도 않고 거절돼야 한다.
            assertThatThrownBy(limitedClient::issueKey).isInstanceOf(CaptchaConcurrencyLimitExceededException.class);
        } finally {
            release.countDown();
            firstCall.join(2_000);
        }

        limitedServer.verify();
    }

    @Test
    @DisplayName("성공한 호출은 자리를 반납해 다음 호출이 통과한다")
    void releasesPermitAfterSuccess() {
        RestClient.Builder builder = mockRestClientBuilder();
        MockRestServiceServer limitedServer = MockRestServiceServer.bindTo(builder).build();
        NaverCaptchaClient limitedClient = new NaverCaptchaClient(propertiesWithLimit(1), builder.build());

        limitedServer.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0"))
                .andRespond(withSuccess("{\"key\":\"abc123\"}", MediaType.APPLICATION_JSON));
        limitedServer.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0"))
                .andRespond(withSuccess("{\"key\":\"def456\"}", MediaType.APPLICATION_JSON));

        assertThat(limitedClient.issueKey()).isEqualTo("abc123");
        assertThat(limitedClient.issueKey()).isEqualTo("def456");
        limitedServer.verify();
    }

    @Test
    @DisplayName("실패한 호출도 자리를 반납한다 - 실패가 쌓여 상한을 영영 못 벗어나면 안 된다")
    void releasesPermitEvenWhenCallFails() {
        RestClient.Builder builder = mockRestClientBuilder();
        MockRestServiceServer limitedServer = MockRestServiceServer.bindTo(builder).build();
        NaverCaptchaClient limitedClient = new NaverCaptchaClient(propertiesWithLimit(1), builder.build());

        limitedServer.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0")).andRespond(withServerError());
        limitedServer.expect(requestTo(BASE_URL + "/v1/captcha/nkey?code=0"))
                .andRespond(withSuccess("{\"key\":\"abc123\"}", MediaType.APPLICATION_JSON));

        assertThatThrownBy(limitedClient::issueKey).isInstanceOf(CaptchaProviderException.class);
        assertThat(limitedClient.issueKey()).isEqualTo("abc123");
        limitedServer.verify();
    }

    private NaverCaptchaProperties properties() {
        return new NaverCaptchaProperties(CLIENT_ID, CLIENT_SECRET, BASE_URL,
                Duration.ofMinutes(2), Duration.ofMinutes(5), 10, 50);
    }

    private NaverCaptchaProperties propertiesWithLimit(int maxConcurrentCalls) {
        return new NaverCaptchaProperties(CLIENT_ID, CLIENT_SECRET, BASE_URL,
                Duration.ofMinutes(2), Duration.ofMinutes(5), 10, maxConcurrentCalls);
    }
}
