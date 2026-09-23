package com.ssafy.timo.domain.captcha;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.captcha.repository.CaptchaPassedStore;
import com.ssafy.timo.global.config.cache.CacheConfig;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.CacheManager;
import org.springframework.test.web.servlet.MockMvc;

/**
 * {@code RequireCaptchaInterceptor} 통합 테스트. {@link CaptchaProbeConfig} 의 프로브 엔드포인트로
 * 확인한다 - 좌석 조회(B9)가 아직 이 인터셉터를 쓰지 않아도 인터셉터 자체는 검증할 수 있어야 한다.
 *
 * <p><b>캐시는 롤백되지 않는다.</b> 통과 기록을 직접 심은 캐시는 각 테스트가 끝나면 비운다.
 */
@IntegrationTest
class RequireCaptchaInterceptorTest {

    private static final long MEMBER_ID = 9001L;
    private static final long OTHER_MEMBER_ID = 9002L;
    private static final long CONCERT_ID = 700L;
    private static final long OTHER_CONCERT_ID = 701L;

    @Autowired
    private MockMvc mvc;
    @Autowired
    private CacheManager cacheManager;
    @Autowired
    private CaptchaPassedStore captchaPassedStore;

    @AfterEach
    void tearDown() {
        cacheManager.getCache(CacheConfig.CAPTCHA_PASSED).clear();
        Authenticated.clear();
    }

    @Test
    @DisplayName("통과 기록이 있으면 200 이고, 반복 호출해도 계속 통과한다 - 조회가 기록을 지우지 않는다")
    void passesRepeatedly() throws Exception {
        captchaPassedStore.markPassed(CONCERT_ID, MEMBER_ID);

        for (int i = 0; i < 3; i++) {
            mvc.perform(get("/test/captcha/query").param("concertId", String.valueOf(CONCERT_ID))
                            .with(Authenticated.as(MEMBER_ID)))
                    .andExpect(status().isOk());
        }
    }

    @Test
    @DisplayName("통과 기록이 없으면 403")
    void rejectsWithoutRecord() throws Exception {
        mvc.perform(get("/test/captcha/query").param("concertId", String.valueOf(CONCERT_ID))
                        .with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("CaptchaRequiredException"));
    }

    @Test
    @DisplayName("다른 공연의 통과 기록으로는 안 된다")
    void rejectsForDifferentConcert() throws Exception {
        captchaPassedStore.markPassed(OTHER_CONCERT_ID, MEMBER_ID);

        mvc.perform(get("/test/captcha/query").param("concertId", String.valueOf(CONCERT_ID))
                        .with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("CaptchaRequiredException"));
    }

    @Test
    @DisplayName("남의 통과 기록으로는 안 된다")
    void rejectsForDifferentMember() throws Exception {
        captchaPassedStore.markPassed(CONCERT_ID, OTHER_MEMBER_ID);

        mvc.perform(get("/test/captcha/query").param("concertId", String.valueOf(CONCERT_ID))
                        .with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("CaptchaRequiredException"));
    }

    @Test
    @DisplayName("path variable 로 받는 엔드포인트도 같은 규칙을 따른다")
    void worksWithPathVariableSource() throws Exception {
        mvc.perform(get("/test/captcha/path/{concertId}", CONCERT_ID).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isForbidden());

        captchaPassedStore.markPassed(CONCERT_ID, MEMBER_ID);

        mvc.perform(get("/test/captcha/path/{concertId}", CONCERT_ID).with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("애노테이션이 없는 엔드포인트는 통과 기록과 무관하게 항상 통과한다")
    void doesNotAffectUnannotatedEndpoint() throws Exception {
        mvc.perform(get("/test/captcha/unprotected").with(Authenticated.as(MEMBER_ID)))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("비로그인이면 401")
    void rejectsAnonymous() throws Exception {
        mvc.perform(get("/test/captcha/query").param("concertId", String.valueOf(CONCERT_ID)))
                .andExpect(status().isUnauthorized());
    }
}
