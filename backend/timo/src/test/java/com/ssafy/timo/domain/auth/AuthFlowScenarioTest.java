package com.ssafy.timo.domain.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.auth.repository.RefreshTokenRepository;
import com.ssafy.timo.domain.auth.repository.SmsVerificationStore;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.entity.MemberStatus;
import com.ssafy.timo.domain.member.entity.Role;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.global.util.Sha256;
import com.ssafy.timo.support.IntegrationTest;
import java.time.Duration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * 인증·가입 전체 흐름을 한 번에 훑는 확인용 테스트.
 *
 * <p>개별 규칙은 각 테스트 클래스가 검증한다. 이 클래스의 목적은 <b>사람이 하나만 돌려 보고
 * 전체가 굴러가는지 확인</b>하는 것이다. 실행: {@code ./gradlew test --tests '*AuthFlowScenarioTest'}
 *
 * <p>인증번호는 응답에 실리지 않고 서버 로그로만 나가므로({@code LoggingSmsSender}),
 * {@code /sms/send} 대신 코드 해시를 저장소에 직접 넣고 시작한다.
 *
 * <p>확인되지 않는 것: {@code IntegrationTest} 가 {@code addFilters = false} 라 <b>시큐리티 필터를
 * 타지 않는다.</b> 경로가 permitAll 로 열렸는지, 잠긴 경로가 401 과 {@code errorCode} 를 내는지는
 * 여기서 알 수 없다(CLAUDE.md 4-1). 그 부분은 {@code global.security} 의 단위 테스트가 맡는다.
 */
@IntegrationTest
class AuthFlowScenarioTest {

    private static final String PHONE = "01012345678";
    private static final String CODE = "123456";
    private static final String NAME = "정희성";
    private static final String USERNAME = "timouser";
    private static final String PASSWORD = "timo1234!";
    private static final String NICKNAME = "티모";
    private static final String DEVICE_ID = "11111111-1111-1111-1111-111111111111";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private SmsVerificationStore smsVerificationStore;

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

    @Test
    @DisplayName("본인인증 → 중복확인 → 가입 → 토큰 발급까지 이어진다")
    void signupFlow() throws Exception {
        smsVerificationStore.saveCode(PHONE, Sha256.hex(CODE), Duration.ofMinutes(3));

        // 1. 인증번호 검증 → 검증 티켓
        String ticket = JsonPath.read(mvc.perform(post("/api/v1/auth/sms/verify")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {"phoneNumber":"%s","code":"%s"}""".formatted(PHONE, CODE)))
                        .andExpect(status().isOk())
                        .andExpect(jsonPath("$.expiresInSeconds").value(1800))
                        .andReturn().getResponse().getContentAsString(),
                "$.verificationTicket");

        // 2. 아이디·닉네임 중복 확인
        assertAvailability("username", USERNAME, true);
        assertAvailability("nickname", NICKNAME, true);

        // 3. 가입
        String response = mvc.perform(signup(ticket, USERNAME, NICKNAME))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accessTokenExpiresIn").value(1800))
                .andReturn().getResponse().getContentAsString();

        long memberId = ((Number) JsonPath.read(response, "$.memberId")).longValue();
        String accessToken = JsonPath.read(response, "$.accessToken");
        String refreshToken = JsonPath.read(response, "$.refreshToken");

        // 4. access token 은 우리 디코더로 풀리고, 개인정보를 담지 않는다
        Jwt jwt = jwtDecoder.decode(accessToken);
        assertThat(jwt.getSubject()).isEqualTo(String.valueOf(memberId));
        assertThat(jwt.getClaimAsStringList("roles")).containsExactly(Role.USER.name());
        assertThat(jwt.getClaims()).containsOnlyKeys("sub", "roles", "iat", "exp", "jti");

        // 5. 회원·로그인 수단·세션이 저장된다
        Member member = memberRepository.findById(memberId).orElseThrow();
        assertThat(member.getPhoneNumber()).isEqualTo(PHONE);
        assertThat(member.getName()).isEqualTo(NAME);
        assertThat(member.getNickname()).isEqualTo(NICKNAME);
        assertThat(member.getRole()).isEqualTo(Role.USER);
        assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);
        assertThat(member.getCreatedAt()).isNotNull();

        String passwordHash = loginInfoRepository.findById(memberId).orElseThrow().getPasswordHash();
        assertThat(passwordHash).isNotEqualTo(PASSWORD);
        assertThat(passwordEncoder.matches(PASSWORD, passwordHash)).isTrue();

        var session = refreshTokenRepository.findByMemberIdAndDeviceId(memberId, DEVICE_ID).orElseThrow();
        assertThat(session.getTokenHash()).isNotEqualTo(refreshToken);
        assertThat(session.matches(Sha256.hex(refreshToken))).isTrue();

        // 6. 가입 후에는 같은 아이디·닉네임을 쓸 수 없다
        assertAvailability("username", USERNAME, false);
        assertAvailability("nickname", NICKNAME, false);

        // 7. 티켓은 1회용
        mvc.perform(signup(ticket, "otheruser", "다른닉네임"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("VerificationTicketInvalidException"));
    }

    private void assertAvailability(String field, String value, boolean expected) throws Exception {
        mvc.perform(get("/api/v1/auth/availability").param(field, value))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.available").value(expected));
    }

    private MockHttpServletRequestBuilder signup(String ticket, String username, String nickname) {
        return post("/api/v1/auth/signup")
                .header("X-Device-Id", DEVICE_ID)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {
                          "verificationTicket": "%s",
                          "phoneNumber": "%s",
                          "name": "%s",
                          "username": "%s",
                          "password": "%s",
                          "nickname": "%s"
                        }""".formatted(ticket, PHONE, NAME, username, PASSWORD, nickname));
    }
}
