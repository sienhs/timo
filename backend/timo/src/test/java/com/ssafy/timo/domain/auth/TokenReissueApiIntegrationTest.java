package com.ssafy.timo.domain.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.entity.RefreshToken;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.auth.repository.RefreshTokenRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.entity.Role;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.global.util.Sha256;
import com.ssafy.timo.support.IntegrationTest;
import java.time.LocalDateTime;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * access 토큰 재발급 통합 테스트. 세션을 끊는 쪽은 {@code LogoutApiIntegrationTest} 가 맡는다.
 *
 * <p>로그인 API 로 세션을 만든 뒤 그 refresh 토큰으로 재발급을 부른다. 저장소에 직접 넣지 않는
 * 이유는 <b>로그인이 만든 세션이 실제로 재발급에 쓰이는지</b>가 확인 대상이기 때문이다.
 *
 * <p>이 파일이 지키는 규칙 두 가지다. 재발급은 refresh 를 <b>회전시키지 않고</b>, 대신
 * <b>만료를 다시 민다</b>. 뒤쪽이 빠지면 앱을 매일 쓰는 사용자도 최초 로그인에서 센 수명이
 * 다하는 날 그냥 튕긴다.
 */
@IntegrationTest
class TokenReissueApiIntegrationTest {

    private static final String LOGIN_PATH = "/api/v1/auth/login";
    private static final String REISSUE_PATH = "/api/v1/auth/reissue";

    private static final String DEVICE_ID_HEADER = "X-Device-Id";
    private static final String DEVICE_ID = "11111111-1111-1111-1111-111111111111";
    private static final String OTHER_DEVICE_ID = "22222222-2222-2222-2222-222222222222";

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

    @Autowired
    private JwtDecoder jwtDecoder;

    private Member member;
    private String refreshToken;

    @BeforeEach
    void setUp() throws Exception {
        member = saveMember();
        refreshToken = login();
    }

    @Test
    @DisplayName("유효한 refresh 토큰이면 새 access 토큰을 발급한다")
    void reissue_returnsNewAccessToken() throws Exception {
        MvcResult result = mvc.perform(reissueRequest(refreshToken, DEVICE_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken").isString())
                .andExpect(jsonPath("$.accessTokenExpiresIn").isNumber())
                .andReturn();

        Jwt jwt = jwtDecoder.decode(readString(result, "accessToken"));
        assertThat(jwt.getSubject()).isEqualTo(String.valueOf(member.getId()));
        assertThat(jwt.getClaimAsStringList("roles")).containsExactly(Role.USER.name());
    }

    @Test
    @DisplayName("응답에 refresh 토큰이 없다. 회전시키지 않으므로 앱은 갖고 있던 것을 계속 쓴다")
    void reissue_doesNotRotateRefreshToken() throws Exception {
        String storedHashBefore = session().getTokenHash();

        mvc.perform(reissueRequest(refreshToken, DEVICE_ID))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.refreshToken").doesNotExist())
                .andExpect(jsonPath("$.length()").value(2));

        assertThat(session().getTokenHash()).isEqualTo(storedHashBefore);

        // 회전하지 않으므로 같은 토큰으로 몇 번이든 다시 받을 수 있어야 한다.
        mvc.perform(reissueRequest(refreshToken, DEVICE_ID)).andExpect(status().isOk());
    }

    @Test
    @DisplayName("재발급하면 세션 만료가 다시 밀린다")
    void reissue_slidesExpiry() throws Exception {
        // 이게 없으면 앱을 매일 쓰는 사용자도 최초 로그인에서 센 수명이 다하는 날 튕긴다.
        RefreshToken session = session();
        session.extend(LocalDateTime.now().plusDays(1));
        LocalDateTime before = session.getExpiresAt();

        mvc.perform(reissueRequest(refreshToken, DEVICE_ID)).andExpect(status().isOk());

        assertThat(session().getExpiresAt()).isAfter(before);
    }

    @Test
    @DisplayName("없는 토큰이면 401 과 TOKEN_INVALID")
    void reissue_rejectsUnknownToken() throws Exception {
        mvc.perform(reissueRequest("never-issued-token", DEVICE_ID))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("다른 기기에서 온 토큰이면 401 과 TOKEN_INVALID")
    void reissue_rejectsDeviceMismatch() throws Exception {
        // 정상 앱은 자기가 만든 UUID 를 계속 쓴다. 갈렸다는 건 토큰이 옮겨졌다는 뜻이다.
        mvc.perform(reissueRequest(refreshToken, OTHER_DEVICE_ID))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("만료된 세션이면 401 과 함께 행이 정리된다")
    void reissue_rejectsExpiredSession() throws Exception {
        session().extend(LocalDateTime.now().minusSeconds(1));

        mvc.perform(reissueRequest(refreshToken, DEVICE_ID))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));

        assertThat(refreshTokenRepository.count()).isZero();
    }

    @Test
    @DisplayName("검증에 걸린 입력도 400 이 아니라 TOKEN_INVALID 로 나간다")
    void reissue_absorbsValidationFailures() throws Exception {
        // 400 으로 나가면 errorCode 가 없어 앱이 로그인 화면으로 갈 신호를 못 받는다.
        mvc.perform(reissueRequest("", DEVICE_ID))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"))
                .andExpect(jsonPath("$.errors").doesNotExist());
    }

    private Member saveMember() {
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

        return saved;
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

        return readString(result, "refreshToken");
    }

    private RefreshToken session() {
        return refreshTokenRepository.findByTokenHash(Sha256.hex(refreshToken)).orElseThrow();
    }

    private MockHttpServletRequestBuilder reissueRequest(String token, String deviceId) {
        return post(REISSUE_PATH)
                .header(DEVICE_ID_HEADER, deviceId)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {"refreshToken":"%s"}""".formatted(token));
    }

    private String readString(MvcResult result, String field) throws Exception {
        return com.jayway.jsonpath.JsonPath.read(result.getResponse().getContentAsString(), "$." + field);
    }
}
