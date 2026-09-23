package com.ssafy.timo.domain.captcha;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.captcha.client.StubCaptchaClient;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.config.cache.CacheConfig;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import java.time.LocalDateTime;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * 캡차 검증 API 통합 테스트.
 *
 * <p>네이버는 부르지 않는다. {@code test} 프로파일에서는 {@link StubCaptchaClient} 가 뜨고
 * 정답은 {@link StubCaptchaClient#ANSWER} 로 고정이다.
 *
 * <p><b>캐시는 롤백되지 않는다.</b> {@code @IntegrationTest} 의 트랜잭션은 DB 만 되돌리므로
 * 이 테스트가 발급 캐시에 직접 심은 키와 통과 기록 캐시는 직접 비운다.
 */
@IntegrationTest
class CaptchaVerifyApiIntegrationTest {

    private static final String VERIFY_PATH = "/api/v1/captcha/verify";
    private static final long MEMBER_ID = 5151L;
    private static final long OTHER_MEMBER_ID = 5152L;

    @Autowired
    private MockMvc mvc;
    @Autowired
    private CacheManager cacheManager;
    @Autowired
    private VenueRepository venueRepository;
    @Autowired
    private ConcertRepository concertRepository;

    private Concert concert;

    @BeforeEach
    void setUp() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔").address("서울시 구로구 경인로 430").totalSeatCount(16000).build());
        concert = concertRepository.save(Concert.builder()
                .title("테스트 공연")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.now().plusDays(30))
                .endDate(LocalDateTime.now().plusDays(30).plusHours(3))
                .openAt(LocalDateTime.now().plusDays(1))
                .venue(venue)
                .build());
    }

    @AfterEach
    void tearDown() {
        captchaKeys().clear();
        captchaPassed().clear();
        Authenticated.clear();
    }

    @Test
    @DisplayName("정답이면 200 이고 통과 기록이 남는다")
    void verifyPasses() throws Exception {
        String key = issueKeyFor(MEMBER_ID);

        mvc.perform(verifyRequest(key, StubCaptchaClient.ANSWER).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.expiresIn").isNumber());

        assertThat(captchaPassed().get(concert.getId() + ":" + MEMBER_ID, Boolean.class)).isTrue();
    }

    @Test
    @DisplayName("오답이면 400 이고, 키가 이미 폐기돼서 재요청은 404 다")
    void verifyRejectsMismatchThenKeyIsGone() throws Exception {
        String key = issueKeyFor(MEMBER_ID);

        mvc.perform(verifyRequest(key, "wrong").with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("CaptchaMismatchException"));

        mvc.perform(verifyRequest(key, StubCaptchaClient.ANSWER).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.exception").value("CaptchaKeyNotFoundException"));
    }

    @Test
    @DisplayName("존재하지 않는(또는 만료된) 키면 404")
    void verifyRejectsUnknownKey() throws Exception {
        mvc.perform(verifyRequest("no-such-key", StubCaptchaClient.ANSWER).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.exception").value("CaptchaKeyNotFoundException"));
    }

    @Test
    @DisplayName("남에게 발급된 키면 403 이고 그 키는 폐기된다")
    void verifyRejectsOwnerMismatch() throws Exception {
        String key = issueKeyFor(OTHER_MEMBER_ID);

        mvc.perform(verifyRequest(key, StubCaptchaClient.ANSWER).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("CaptchaKeyOwnerMismatchException"));

        assertThat(captchaKeys().get(key)).isNull();
    }

    @Test
    @DisplayName("없는 공연이면 404 이고 키는 소비되지 않는다")
    void verifyRejectsUnknownConcert() throws Exception {
        String key = issueKeyFor(MEMBER_ID);

        mvc.perform(post(VERIFY_PATH)
                        .with(Authenticated.as(MEMBER_ID))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "concertId": 999999,
                                  "captchaKey": "%s",
                                  "value": "%s"
                                }
                                """.formatted(key, StubCaptchaClient.ANSWER)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.exception").value("ConcertNotFoundException"));

        assertThat(captchaKeys().get(key, Long.class)).isEqualTo(MEMBER_ID);
    }

    @Test
    @DisplayName("비로그인이면 401")
    void verifyRejectsAnonymous() throws Exception {
        mvc.perform(verifyRequest("any-key", StubCaptchaClient.ANSWER))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("captchaKey 가 공백이면 400")
    void verifyRejectsBlankKey() throws Exception {
        mvc.perform(verifyRequest("   ", StubCaptchaClient.ANSWER).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("value 가 20자를 넘으면 400")
    void verifyRejectsTooLongValue() throws Exception {
        mvc.perform(verifyRequest("some-key", "a".repeat(21)).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isBadRequest());
    }

    /** 캡차 발급 캐시에 직접 키를 심는다. 발급 API 자체는 B5 통합 테스트가 이미 검증한다. */
    private String issueKeyFor(long memberId) {
        String key = "key-" + memberId + "-" + System.nanoTime();
        captchaKeys().put(key, memberId);
        return key;
    }

    private MockHttpServletRequestBuilder verifyRequest(String key, String value) {
        return post(VERIFY_PATH)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {
                          "concertId": %d,
                          "captchaKey": "%s",
                          "value": "%s"
                        }
                        """.formatted(concert.getId(), key, value));
    }

    private Cache captchaKeys() {
        return cacheManager.getCache(CacheConfig.CAPTCHA_KEYS);
    }

    private Cache captchaPassed() {
        return cacheManager.getCache(CacheConfig.CAPTCHA_PASSED);
    }
}
