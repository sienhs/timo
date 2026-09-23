package com.ssafy.timo.domain.captcha;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.ssafy.timo.domain.captcha.client.StubCaptchaClient;
import com.ssafy.timo.global.config.cache.CacheConfig;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import java.util.Base64;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * 캡차 발급 API 통합 테스트.
 *
 * <p>여기서만 확인되는 것은 <b>저장소에 남는 것</b>이다. 발급된 키가 요청자 id 와 함께 남아야
 * 나중에 검증이 주인을 가려낼 수 있다. 만료까지 함께 걸리는지는 {@code CacheConfigTest} 가 본다.
 *
 * <p>네이버는 부르지 않는다. {@code test} 프로파일에서는 {@link StubCaptchaClient} 가 뜬다.
 *
 * <p><b>캐시는 롤백되지 않는다.</b> {@code @IntegrationTest} 의 트랜잭션은 DB 만 되돌리므로
 * 이 테스트가 넣은 것은 직접 비운다. 특히 발급 횟수는 비우지 않으면 다음 테스트가 남의 카운터를
 * 물려받아 한도에 걸린다.
 */
@IntegrationTest
class CaptchaIssueApiIntegrationTest {

    private static final String CAPTCHA_PATH = "/api/v1/captcha";
    private static final long MEMBER_ID = 4242L;
    private static final long OTHER_MEMBER_ID = 4243L;

    /** {@code application.yml} 의 {@code naver.captcha.issue-limit-per-minute} 와 같은 값이다. */
    private static final int ISSUE_LIMIT_PER_MINUTE = 10;

    @Autowired
    private MockMvc mvc;
    @Autowired
    private CacheManager cacheManager;

    private String issuedKey;

    @AfterEach
    void tearDown() {
        issuedKey = null;
        captchaKeys().clear();
        captchaRates().clear();
        Authenticated.clear();
    }

    @Test
    @DisplayName("발급하면 응답 네 필드가 모두 채워진다")
    void issueFillsEveryField() throws Exception {
        MvcResult result = mvc.perform(post(CAPTCHA_PATH).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.captchaKey").isNotEmpty())
                .andExpect(jsonPath("$.image").isNotEmpty())
                .andExpect(jsonPath("$.imageType").value("image/jpeg"))
                .andExpect(jsonPath("$.expiresIn").value(120))
                .andReturn();

        String body = result.getResponse().getContentAsString();
        issuedKey = JsonPath.read(body, "$.captchaKey");

        assertThat(Base64.getDecoder().decode((String) JsonPath.read(body, "$.image"))).isNotEmpty();
    }

    @Test
    @DisplayName("발급한 키가 요청자 id 와 함께 저장된다")
    void storesOwner() throws Exception {
        MvcResult result = mvc.perform(post(CAPTCHA_PATH).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isOk())
                .andReturn();
        issuedKey = JsonPath.read(result.getResponse().getContentAsString(), "$.captchaKey");

        assertThat(captchaKeys().get(issuedKey, Long.class)).isEqualTo(MEMBER_ID);
    }

    @Test
    @DisplayName("비로그인이면 401 이고 아무것도 발급되지 않는다")
    void rejectsAnonymous() throws Exception {
        mvc.perform(post(CAPTCHA_PATH)).andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("1분 한도(10회)까지는 나가고 그 다음부터 429 다")
    void rejectsAfterIssueLimit() throws Exception {
        for (int attempt = 1; attempt <= ISSUE_LIMIT_PER_MINUTE; attempt++) {
            mvc.perform(post(CAPTCHA_PATH).with(Authenticated.as(MEMBER_ID)))
                    .andExpect(status().isOk());
        }

        mvc.perform(post(CAPTCHA_PATH).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isTooManyRequests());
    }

    @Test
    @DisplayName("한도는 회원별이다 - 남이 다 써도 내 발급은 나간다")
    void limitsPerMember() throws Exception {
        for (int attempt = 1; attempt <= ISSUE_LIMIT_PER_MINUTE + 1; attempt++) {
            mvc.perform(post(CAPTCHA_PATH).with(Authenticated.as(MEMBER_ID)));
        }

        mvc.perform(post(CAPTCHA_PATH).with(Authenticated.as(OTHER_MEMBER_ID)))
                .andExpect(status().isOk());
    }

    private Cache captchaKeys() {
        return cacheManager.getCache(CacheConfig.CAPTCHA_KEYS);
    }

    private Cache captchaRates() {
        return cacheManager.getCache(CacheConfig.CAPTCHA_RATES);
    }
}
