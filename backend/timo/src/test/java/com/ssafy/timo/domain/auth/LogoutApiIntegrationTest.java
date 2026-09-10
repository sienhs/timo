package com.ssafy.timo.domain.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.auth.repository.RefreshTokenRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.support.IntegrationTest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * 로그아웃 통합 테스트.
 *
 * <p>로그인 API 로 세션을 만든 뒤 그 refresh 토큰으로 로그아웃한다. 저장소에 직접 넣지 않는
 * 이유는 <b>로그인이 만든 세션이 실제로 끊기는지</b>가 확인 대상이기 때문이다.
 *
 * <p>이 파일이 지키는 규칙은 두 가지다. 로그아웃은 세션을 실제로 지우고, <b>몇 번을 불러도
 * 성공한다</b>. 뒤쪽이 깨지면 앱이 로그아웃 화면에서 멈춘다.
 */
@IntegrationTest
class LogoutApiIntegrationTest {

    private static final String LOGIN_PATH = "/api/v1/auth/login";
    private static final String LOGOUT_PATH = "/api/v1/auth/logout";
    private static final String REISSUE_PATH = "/api/v1/auth/reissue";

    private static final String DEVICE_ID_HEADER = "X-Device-Id";
    private static final String DEVICE_ID = "11111111-1111-1111-1111-111111111111";

    private static final String USERNAME = "timo_user";
    private static final String PASSWORD = "timo1234!";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private LoginInfoRepository loginInfoRepository;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    private String refreshToken;

    @BeforeEach
    void setUp() throws Exception {
        saveMember();
        refreshToken = login();
    }

    @Test
    @DisplayName("로그아웃하면 세션이 지워지고 그 토큰으로는 재발급되지 않는다")
    void logout_removesSession() throws Exception {
        mvc.perform(logoutRequest(refreshToken)).andExpect(status().isNoContent());

        assertThat(refreshTokenRepository.count()).isZero();

        mvc.perform(post(REISSUE_PATH)
                        .header(DEVICE_ID_HEADER, DEVICE_ID)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"%s"}""".formatted(refreshToken)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("이미 끊긴 세션을 로그아웃해도 성공이다")
    void logout_isIdempotent() throws Exception {
        // 실패로 돌려주면 앱이 로그아웃 화면에서 멈추고, 어느 토큰이 살아 있는지도 알려주게 된다.
        mvc.perform(logoutRequest(refreshToken)).andExpect(status().isNoContent());
        mvc.perform(logoutRequest(refreshToken)).andExpect(status().isNoContent());
        mvc.perform(logoutRequest("never-issued-token")).andExpect(status().isNoContent());
        mvc.perform(logoutRequest("")).andExpect(status().isNoContent());
    }

    private void saveMember() {
        Member saved = memberRepository.save(Member.builder()
                .phoneNumber("01012345678")
                .name("정희성")
                .nickname("티모")
                .build());

        loginInfoRepository.saveAndFlush(LoginInfo.builder()
                .member(saved)
                .username(USERNAME)
                .passwordHash(passwordEncoder.encode(PASSWORD))
                .build());
    }

    /** 로그인으로 세션을 만들고 refresh 토큰 원문을 받아 온다. 서버에는 해시만 남는다. */
    private String login() throws Exception {
        MvcResult result = mvc.perform(post(LOGIN_PATH)
                        .header(DEVICE_ID_HEADER, DEVICE_ID)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"%s","password":"%s"}""".formatted(USERNAME, PASSWORD)))
                .andExpect(status().isOk())
                .andReturn();

        return com.jayway.jsonpath.JsonPath.read(result.getResponse().getContentAsString(), "$.refreshToken");
    }

    private MockHttpServletRequestBuilder logoutRequest(String token) {
        return post(LOGOUT_PATH)
                .header(DEVICE_ID_HEADER, DEVICE_ID)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"refreshToken":"%s"}""".formatted(token));
    }
}
