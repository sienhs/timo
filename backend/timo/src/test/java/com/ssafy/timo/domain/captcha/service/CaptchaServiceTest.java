package com.ssafy.timo.domain.captcha.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;

import com.ssafy.timo.domain.captcha.client.CaptchaClient;
import com.ssafy.timo.domain.captcha.dto.CaptchaIssueResponseDto;
import com.ssafy.timo.domain.captcha.dto.CaptchaVerifyRequestDto;
import com.ssafy.timo.domain.captcha.dto.CaptchaVerifyResponseDto;
import com.ssafy.timo.domain.captcha.exception.CaptchaKeyNotFoundException;
import com.ssafy.timo.domain.captcha.exception.CaptchaKeyOwnerMismatchException;
import com.ssafy.timo.domain.captcha.exception.CaptchaMismatchException;
import com.ssafy.timo.domain.captcha.exception.CaptchaProviderException;
import com.ssafy.timo.domain.captcha.exception.CaptchaTooManyRequestsException;
import com.ssafy.timo.domain.captcha.repository.CaptchaKeyStore;
import com.ssafy.timo.domain.captcha.repository.CaptchaPassedStore;
import com.ssafy.timo.domain.captcha.repository.CaptchaRateStore;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Base64;
import java.util.Optional;

import com.ssafy.timo.global.config.captcha.NaverCaptchaProperties;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** 공급자 호출과 저장의 순서를 본다. 캐시에 실제로 담기는지는 발급 API 통합 테스트가 본다. */
@ExtendWith(MockitoExtension.class)
class CaptchaServiceTest {

    private static final Long MEMBER_ID = 7L;
    private static final Long OTHER_MEMBER_ID = 8L;
    private static final Long CONCERT_ID = 100L;
    private static final byte[] IMAGE = "fake-jpeg".getBytes(StandardCharsets.UTF_8);

    @Mock
    private CaptchaClient captchaClient;

    @Mock
    private CaptchaKeyStore captchaKeyStore;

    @Mock
    private CaptchaRateStore captchaRateStore;

    @Mock
    private CaptchaPassedStore captchaPassedStore;

    @Mock
    private ConcertRepository concertRepository;

    private CaptchaService captchaService;

    /** 설정은 레코드라 목으로 만들지 않고 실제 값을 넣는다 - 검증할 것이 그 값 자체다. */
    @BeforeEach
    void setUp() {
        NaverCaptchaProperties properties = new NaverCaptchaProperties(
                "id", "secret", "https://openapi.naver.com",
                Duration.ofMinutes(2), Duration.ofMinutes(5), 10, 50);
        captchaService = new CaptchaService(
                captchaClient, captchaKeyStore, captchaRateStore, captchaPassedStore, concertRepository, properties);
    }

    @Test
    @DisplayName("발급하면 키·이미지·형식·유효시간이 모두 채워진다")
    void issueFillsEveryField() {
        given(captchaRateStore.increment(MEMBER_ID)).willReturn(1);
        given(captchaClient.issueKey()).willReturn("abc123");
        given(captchaClient.fetchImage("abc123")).willReturn(IMAGE);

        CaptchaIssueResponseDto response = captchaService.issue(MEMBER_ID);

        assertThat(response.captchaKey()).isEqualTo("abc123");
        assertThat(response.image()).isEqualTo(Base64.getEncoder().encodeToString(IMAGE));
        assertThat(response.imageType()).isEqualTo("image/jpeg");
        assertThat(response.expiresIn()).isEqualTo(120);
    }

    @Test
    @DisplayName("발급한 키를 요청자와 함께 저장한다")
    void storesKeyWithOwner() {
        given(captchaRateStore.increment(MEMBER_ID)).willReturn(1);
        given(captchaClient.issueKey()).willReturn("abc123");
        given(captchaClient.fetchImage("abc123")).willReturn(IMAGE);

        captchaService.issue(MEMBER_ID);

        then(captchaKeyStore).should().save("abc123", MEMBER_ID);
    }

    @Test
    @DisplayName("키 발급이 실패하면 저장하지 않는다")
    void doesNotStoreWhenKeyIssueFails() {
        given(captchaRateStore.increment(MEMBER_ID)).willReturn(1);
        given(captchaClient.issueKey()).willThrow(new CaptchaProviderException(new IOException("boom")));

        assertThatThrownBy(() -> captchaService.issue(MEMBER_ID))
                .isInstanceOf(CaptchaProviderException.class);
        then(captchaKeyStore).should(never()).save(anyString(), anyLong());
    }

    @Test
    @DisplayName("이미지 조회가 실패해도 저장하지 않는다 - 풀 수 없는 캡차가 2분 남으면 안 된다")
    void doesNotStoreWhenImageFetchFails() {
        given(captchaRateStore.increment(MEMBER_ID)).willReturn(1);
        given(captchaClient.issueKey()).willReturn("abc123");
        given(captchaClient.fetchImage("abc123"))
                .willThrow(new CaptchaProviderException(new IOException("boom")));

        assertThatThrownBy(() -> captchaService.issue(MEMBER_ID))
                .isInstanceOf(CaptchaProviderException.class);
        then(captchaKeyStore).should(never()).save(anyString(), anyLong());
    }

    @Test
    @DisplayName("한도와 같은 횟수까지는 통과한다")
    void allowsUpToLimit() {
        given(captchaRateStore.increment(MEMBER_ID)).willReturn(10);
        given(captchaClient.issueKey()).willReturn("abc123");
        given(captchaClient.fetchImage("abc123")).willReturn(IMAGE);

        assertThat(captchaService.issue(MEMBER_ID).captchaKey()).isEqualTo("abc123");
    }

    @Test
    @DisplayName("한도를 넘으면 429 이고 네이버를 부르지 않는다 - 막을 요청에 API 호출 한도를 쓰지 않는다")
    void rejectsOverLimitBeforeCallingProvider() {
        given(captchaRateStore.increment(MEMBER_ID)).willReturn(11);

        assertThatThrownBy(() -> captchaService.issue(MEMBER_ID))
                .isInstanceOf(CaptchaTooManyRequestsException.class);
        then(captchaClient).shouldHaveNoInteractions();
        then(captchaKeyStore).should(never()).save(anyString(), anyLong());
    }

    @Test
    @DisplayName("정답이면 통과 기록을 남기고 남은 시간을 돌려준다")
    void verifyPassesAndMarksPassed() {
        CaptchaVerifyRequestDto request = new CaptchaVerifyRequestDto(CONCERT_ID, "key1", "timo");
        given(concertRepository.existsById(CONCERT_ID)).willReturn(true);
        given(captchaKeyStore.getAndEvict("key1")).willReturn(Optional.of(MEMBER_ID));
        given(captchaClient.verify("key1", "timo")).willReturn(true);

        CaptchaVerifyResponseDto response = captchaService.verify(MEMBER_ID, request);

        assertThat(response.expiresIn()).isEqualTo(Duration.ofMinutes(5).toSeconds());
        then(captchaPassedStore).should().markPassed(CONCERT_ID, MEMBER_ID);
    }

    @Test
    @DisplayName("없는 공연이면 404 이고 키를 건드리지 않는다")
    void verifyRejectsUnknownConcert() {
        CaptchaVerifyRequestDto request = new CaptchaVerifyRequestDto(CONCERT_ID, "key1", "timo");
        given(concertRepository.existsById(CONCERT_ID)).willReturn(false);

        assertThatThrownBy(() -> captchaService.verify(MEMBER_ID, request))
                .isInstanceOf(ConcertNotFoundException.class);
        then(captchaKeyStore).shouldHaveNoInteractions();
        then(captchaPassedStore).shouldHaveNoInteractions();
    }

    @Test
    @DisplayName("키가 없거나 만료·소비됐으면 404")
    void verifyRejectsMissingKey() {
        CaptchaVerifyRequestDto request = new CaptchaVerifyRequestDto(CONCERT_ID, "key1", "timo");
        given(concertRepository.existsById(CONCERT_ID)).willReturn(true);
        given(captchaKeyStore.getAndEvict("key1")).willReturn(Optional.empty());

        assertThatThrownBy(() -> captchaService.verify(MEMBER_ID, request))
                .isInstanceOf(CaptchaKeyNotFoundException.class);
        then(captchaClient).shouldHaveNoInteractions();
        then(captchaPassedStore).shouldHaveNoInteractions();
    }

    @Test
    @DisplayName("남에게 발급된 키면 403 이고 공급자를 부르지 않는다")
    void verifyRejectsOwnerMismatch() {
        CaptchaVerifyRequestDto request = new CaptchaVerifyRequestDto(CONCERT_ID, "key1", "timo");
        given(concertRepository.existsById(CONCERT_ID)).willReturn(true);
        given(captchaKeyStore.getAndEvict("key1")).willReturn(Optional.of(OTHER_MEMBER_ID));

        assertThatThrownBy(() -> captchaService.verify(MEMBER_ID, request))
                .isInstanceOf(CaptchaKeyOwnerMismatchException.class);
        then(captchaClient).shouldHaveNoInteractions();
        then(captchaPassedStore).shouldHaveNoInteractions();
    }

    @Test
    @DisplayName("오답이면 400 이고 통과 기록을 남기지 않는다 - 키는 이미 폐기된 뒤다")
    void verifyRejectsMismatch() {
        CaptchaVerifyRequestDto request = new CaptchaVerifyRequestDto(CONCERT_ID, "key1", "wrong");
        given(concertRepository.existsById(CONCERT_ID)).willReturn(true);
        given(captchaKeyStore.getAndEvict("key1")).willReturn(Optional.of(MEMBER_ID));
        given(captchaClient.verify("key1", "wrong")).willReturn(false);

        assertThatThrownBy(() -> captchaService.verify(MEMBER_ID, request))
                .isInstanceOf(CaptchaMismatchException.class);
        then(captchaPassedStore).shouldHaveNoInteractions();
    }

    @Test
    @DisplayName("공급자 호출이 실패하면 502 다")
    void verifyPropagatesProviderFailure() {
        CaptchaVerifyRequestDto request = new CaptchaVerifyRequestDto(CONCERT_ID, "key1", "timo");
        given(concertRepository.existsById(CONCERT_ID)).willReturn(true);
        given(captchaKeyStore.getAndEvict("key1")).willReturn(Optional.of(MEMBER_ID));
        given(captchaClient.verify("key1", "timo")).willThrow(new CaptchaProviderException(new IOException("boom")));

        assertThatThrownBy(() -> captchaService.verify(MEMBER_ID, request))
                .isInstanceOf(CaptchaProviderException.class);
        then(captchaPassedStore).shouldHaveNoInteractions();
    }
}
