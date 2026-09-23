package com.ssafy.timo.domain.captcha.client;

import com.ssafy.timo.domain.captcha.exception.CaptchaConcurrencyLimitExceededException;
import com.ssafy.timo.domain.captcha.exception.CaptchaProviderException;
import com.ssafy.timo.global.config.captcha.NaverCaptchaProperties;
import java.net.URI;
import java.time.Duration;
import java.util.List;
import java.util.concurrent.Semaphore;
import java.util.function.Function;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Profile;
import org.springframework.http.MediaType;
import org.springframework.http.client.ClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.util.UriBuilder;

/**
 * 네이버 캡차 오픈 API({@code openapi.naver.com/v1/captcha}) 호출.
 *
 * <p>호출은 셋뿐이다. 키를 받고({@code nkey?code=0}), 그 키로 이미지를 받고
 * ({@code ncaptcha.bin}), 사용자가 입력한 값을 검증한다({@code nkey?code=1}).
 *
 * <p><b>실패는 전부 {@link CaptchaProviderException}(502) 하나로 모은다.</b> 타임아웃인지 인증
 * 실패인지 응답 형식이 바뀐 것인지는 우리 쪽 로그로만 남긴다 - 밖에 알려 줘야 할 이유가 없고,
 * 알려 주면 캡차를 우회하려는 쪽에 힌트가 된다. 로그를 여기서 남기는 것은
 * {@code GlobalExceptionHandler} 가 비즈니스 예외를 스택트레이스 없이 흘려보내기 때문이다.
 *
 * <p><b>로그에 자격증명과 사용자 입력을 남기지 않는다.</b> 남기는 것은 어느 호출이 실패했는지와
 * 그 예외뿐이다. 캡차 정답 후보가 로그에 쌓이면 캡차를 두는 의미가 없어진다.
 *
 * <p>{@code local} 과 {@code test} 를 제외한 프로파일에서 뜬다. {@link StubCaptchaClient} 와
 * 프로파일 조건이 서로 여집합이어야 한다는 점은 {@code SolapiSmsSender} 와 같은 사정이다.
 *
 * <p><b>네이버로 나가는 동시 호출 수를 {@code naver.captcha.max-concurrent-calls} 로 제한한다.</b>
 * 이 호출은 read timeout 이 3초이고, 요청을 받는 스레드와 좌석 조회·예매가 받는 스레드가 같은
 * 풀을 쓴다(기본 max-threads 200). 네이버가 느려지는 순간 제한 없이 스레드를 계속 물리면 캡차 하나
 * 때문에 예매 전체가 멈출 수 있어({@code docs/BE_CAPTCHA_TASK_BREAKDOWN.md} "B9 전에 볼 것"),
 * 상한을 넘는 요청은 기다리게 하지 않고 바로 502 로 거절한다({@link Semaphore#tryAcquire()},
 * {@link CaptchaConcurrencyLimitExceededException}). 이 거절엔 {@code GlobalExceptionHandler} 가
 * {@code Retry-After} 헤더를 함께 내려보낸다.
 *
 * <p><b>{@code nkey} 응답에 {@code Content-Type} 헤더가 없다(실제 호출로 확인, 2026-09-24).</b>
 * 헤더가 없으면 커넥션 팩토리가 {@code application/octet-stream} 으로 채워 넣는데, 본문은 JSON 이다.
 * 기본 Jackson 컨버터는 선언된 타입이 JSON 계열이 아니면 읽기를 거부해 매 호출이
 * {@code UnknownContentTypeException} → 502 로 죽는다({@code NaverCaptchaClientTest} 는 이 문제를
 * 못 잡았다 - 목 서버가 항상 {@code APPLICATION_JSON} 을 명시해서 응답하기 때문이다). 그래서 Jackson
 * 컨버터가 읽을 수 있는 타입에 {@code application/octet-stream} 을 더해 등록한다.
 */
@Slf4j
@Component
@Profile("!local & !test")
public class NaverCaptchaClient implements CaptchaClient {

    private static final String CLIENT_ID_HEADER = "X-Naver-Client-Id";
    private static final String CLIENT_SECRET_HEADER = "X-Naver-Client-Secret";

    private static final String NKEY_PATH = "/v1/captcha/nkey";
    private static final String IMAGE_PATH = "/v1/captcha/ncaptcha.bin";

    /** 키 발급과 검증은 같은 엔드포인트를 {@code code} 로 가른다. */
    private static final String ISSUE_CODE = "0";
    private static final String VERIFY_CODE = "1";

    /**
     * 연결·읽기 제한. 이 호출은 사용자가 좌석 화면 앞에서 기다리는 동안 일어나므로, 상대가 느릴 때
     * 같이 느려지는 것보다 빨리 502 로 끊고 다시 시도하게 하는 편이 낫다. 프로파일마다 다를 값이
     * 아니라 속성으로 빼지 않았다.
     */
    private static final Duration CONNECT_TIMEOUT = Duration.ofSeconds(2);
    private static final Duration READ_TIMEOUT = Duration.ofSeconds(3);

    private final RestClient restClient;
    private final String clientId;
    private final String clientSecret;

    /**
     * 네이버로 동시에 나가는 호출 수 상한. 대기시키지 않는다 - {@link Semaphore#tryAcquire()} 만
     * 쓰고 {@link Semaphore#acquire()} 는 쓰지 않는다. 대기시키면 그 대기 자체가 스레드를 물고 있는
     * 시간이라 상한을 두는 의미가 없어진다.
     */
    private final Semaphore inFlightLimiter;
    private final int maxConcurrentCalls;

    /**
     * 생성자가 둘이라 스프링이 쓸 쪽을 {@code @Autowired} 로 짚어 준다 - {@code S3ImageStorage} 와
     * 같은 사정이다. {@code RestClient} 는 빈으로 등록돼 있지 않다.
     */
    @Autowired
    public NaverCaptchaClient(NaverCaptchaProperties properties) {
        this(properties, RestClient.builder()
                .baseUrl(properties.baseUrl())
                .requestFactory(requestFactory())
                // 맨 뒤에 붙인다 - 앞에 두면 byte[] 를 받는 fetchImage() 응답까지 이 컨버터가
                // 먼저 가로채려 든다(Jackson 은 byte[] 도 역직렬화할 수 있다고 주장한다).
                // ByteArrayHttpMessageConverter 등 기본 컨버터가 먼저 시도하고, JSON 계열 타입인데
                // Content-Type 이 어긋난 경우에만 이 컨버터까지 순서가 내려온다.
                .messageConverters(converters -> converters.add(jsonConverter()))
                .build());
    }

    /** {@code MockRestServiceServer} 에 물린 {@code RestClient} 를 넣기 위한 테스트용 생성자. */
    NaverCaptchaClient(NaverCaptchaProperties properties, RestClient restClient) {
        this.restClient = restClient;
        this.clientId = properties.clientId();
        this.clientSecret = properties.clientSecret();
        this.maxConcurrentCalls = properties.maxConcurrentCalls();
        this.inFlightLimiter = new Semaphore(maxConcurrentCalls);
    }

    private static ClientHttpRequestFactory requestFactory() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(CONNECT_TIMEOUT);
        factory.setReadTimeout(READ_TIMEOUT);

        return factory;
    }

    /**
     * 네이버가 {@code Content-Type} 을 안 보내 {@code application/octet-stream} 으로 잡히는 응답도
     * JSON 으로 읽는다. 클래스 주석 참고.
     *
     * <p>패키지 전용이다 - {@code NaverCaptchaClientTest} 가 {@code MockRestServiceServer} 에 물릴
     * {@code RestClient} 를 만들 때도 이 컨버터를 그대로 써야, 프로덕션 생성자만 통과하는 값이 아니라
     * 실제로 이 문제를 재현·확인하는 테스트가 된다.
     */
    static MappingJackson2HttpMessageConverter jsonConverter() {
        MappingJackson2HttpMessageConverter converter = new MappingJackson2HttpMessageConverter();
        converter.setSupportedMediaTypes(List.of(MediaType.APPLICATION_JSON, MediaType.APPLICATION_OCTET_STREAM));
        return converter;
    }

    /**
     * 캡차 키를 발급받는다. 이 키로 이미지를 받고, 나중에 같은 키로 검증한다.
     *
     * @throws CaptchaProviderException 호출이 실패했거나 응답에 키가 없으면
     */
    @Override
    public String issueKey() {
        NaverCaptchaResponse response = call(
                uri -> uri.path(NKEY_PATH).queryParam("code", ISSUE_CODE).build(),
                NaverCaptchaResponse.class,
                "키 발급");

        if (response == null || response.key() == null || response.key().isBlank()) {
            throw new CaptchaProviderException(new IllegalStateException("키 발급 응답에 key 가 없다"));
        }
        return response.key();
    }

    /**
     * 키에 해당하는 캡차 이미지를 받는다. 형식은 네이버가 정하며 지금은 JPEG 이다.
     *
     * @throws CaptchaProviderException 호출이 실패했거나 본문이 비어 있으면
     */
    @Override
    public byte[] fetchImage(String key) {
        byte[] image = call(
                uri -> uri.path(IMAGE_PATH).queryParam("key", "{key}").build(key),
                byte[].class,
                "이미지 조회");

        if (image == null || image.length == 0) {
            throw new CaptchaProviderException(new IllegalStateException("이미지 응답이 비어 있다"));
        }
        return image;
    }

    /**
     * 사용자가 입력한 값이 캡차와 맞는지 묻는다. 틀렸다는 응답은 실패가 아니라 {@code false} 다 -
     * 오답을 502 로 만들면 앱이 다시 입력하라고 안내할 수 없다.
     *
     * <p>{@code key} 와 {@code value} 는 URI 변수로 넘겨 인코딩을 {@code RestClient} 에 맡긴다.
     * 직접 이어 붙이면 사용자가 넣은 {@code &} 나 {@code =} 가 쿼리 구분자로 읽혀, 입력값이 잘린 채
     * 검증되거나 파라미터가 하나 더 붙는다.
     *
     * @throws CaptchaProviderException 호출이 실패했거나 응답에 결과가 없으면
     */
    @Override
    public boolean verify(String key, String value) {
        NaverCaptchaResponse response = call(
                uri -> uri.path(NKEY_PATH)
                        .queryParam("code", VERIFY_CODE)
                        .queryParam("key", "{key}")
                        .queryParam("value", "{value}")
                        .build(key, value),
                NaverCaptchaResponse.class,
                "검증");

        if (response == null || response.result() == null) {
            throw new CaptchaProviderException(new IllegalStateException("검증 응답에 result 가 없다"));
        }
        return response.result();
    }

    private <T> T call(Function<UriBuilder, URI> uri, Class<T> responseType, String operation) {
        // 상한을 넘으면 자리가 날 때까지 기다리지 않는다 - 기다리는 동안도 스레드를 물고 있어,
        // 대기시키는 순간 상한을 둔 의미가 없어진다.
        if (!inFlightLimiter.tryAcquire()) {
            log.warn("네이버 캡차 동시 호출 상한({}) 초과: operation={}", maxConcurrentCalls, operation);
            throw new CaptchaConcurrencyLimitExceededException();
        }
        try {
            return restClient.get()
                    .uri(uri)
                    .header(CLIENT_ID_HEADER, clientId)
                    .header(CLIENT_SECRET_HEADER, clientSecret)
                    .retrieve()
                    .body(responseType);
        } catch (RestClientException e) {
            // 어느 호출이 깨졌는지만 남긴다. URI 에는 사용자 입력이 실려 있어 함께 찍지 않는다.
            log.warn("네이버 캡차 호출 실패: operation={}", operation, e);
            throw new CaptchaProviderException(e);
        } finally {
            inFlightLimiter.release();
        }
    }

    /**
     * 키 발급과 검증이 같은 엔드포인트를 쓰므로 응답도 하나로 받는다. 발급 응답에는 {@code key} 만,
     * 검증 응답에는 {@code result} 만 들어 있어 나머지 한쪽은 {@code null} 이다.
     */
    record NaverCaptchaResponse(String key, Boolean result) {
    }
}
