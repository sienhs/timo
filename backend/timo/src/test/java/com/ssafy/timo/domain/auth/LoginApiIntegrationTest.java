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
import java.util.Optional;
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
 * 로그인 API 통합 테스트.
 *
 * <p>가입 API 를 거치지 않고 회원과 로그인 수단을 저장소에 직접 넣어 준비한다. 여기서 검증할 것은
 * 가입 흐름이 아니라 <b>이미 있는 계정으로 다시 들어오는 경로</b>이기 때문이다.
 *
 * <p>이 파일의 중심은 {@link #failureResponsesAreIndistinguishable()} 이다. 로그인 실패는 사유가
 * 무엇이든 밖에서 구분되지 않아야 한다. 구분되면 어떤 아이디가 가입돼 있는지 수집할 수 있고,
 * 서버가 받는 입력 상한도 드러난다.
 *
 * <p><b>주의</b>: {@code IntegrationTest} 가 {@code addFilters = false} 라 시큐리티 필터를 타지 않는다.
 * 따라서 이 테스트는 <b>로그인 경로가 permitAll 로 열려 있는지 검증하지 못한다.</b>
 * 그 확인은 필터를 그대로 태우는 {@code SecurityLockdownTest} 가 맡는다.
 */
@IntegrationTest
class LoginApiIntegrationTest {

    private static final String LOGIN_PATH = "/api/v1/auth/login";
    private static final String DEVICE_ID_HEADER = "X-Device-Id";
    private static final String DEVICE_ID = "11111111-1111-1111-1111-111111111111";

    private static final String PHONE = "01012345678";
    private static final String NAME = "정희성";
    private static final String NICKNAME = "티모";
    private static final String USERNAME = "timo_user";
    private static final String PASSWORD = "timo1234!";

    /** {@code login_info.username} 컬럼이 50자다. 이보다 길면 저장될 수 없어 존재할 수도 없다. */
    private static final String TOO_LONG_USERNAME = "a".repeat(51);

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

    @BeforeEach
    void setUp() {
        member = saveMember();
    }

    @Test
    @DisplayName("아이디와 비밀번호가 맞으면 200 과 함께 토큰을 반환한다")
    void login_returnsTokens() throws Exception {
        MvcResult result = mvc.perform(loginRequest(USERNAME, PASSWORD))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.memberId").value(member.getId()))
                .andExpect(jsonPath("$.accessToken").isString())
                .andExpect(jsonPath("$.refreshToken").isString())
                .andExpect(jsonPath("$.accessTokenExpiresIn").isNumber())
                .andReturn();

        // 발급한 토큰이 우리 디코더로 실제로 풀려야 의미가 있다.
        Jwt jwt = jwtDecoder.decode(readString(result, "accessToken"));
        assertThat(jwt.getSubject()).isEqualTo(String.valueOf(member.getId()));
        assertThat(jwt.getClaimAsStringList("roles")).containsExactly(Role.USER.name());
    }

    @Test
    @DisplayName("가입 응답과 필드가 같아야 앱이 두 흐름을 같은 코드로 처리한다")
    void login_responseHasSameShapeAsSignup() throws Exception {
        mvc.perform(loginRequest(USERNAME, PASSWORD))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(4))
                .andExpect(jsonPath("$.memberId").exists())
                .andExpect(jsonPath("$.accessToken").exists())
                .andExpect(jsonPath("$.refreshToken").exists())
                .andExpect(jsonPath("$.accessTokenExpiresIn").exists());
    }

    @Test
    @DisplayName("로그인하면 그 기기의 세션이 저장된다")
    void login_createsSessionForDevice() throws Exception {
        MvcResult result = mvc.perform(loginRequest(USERNAME, PASSWORD)).andExpect(status().isOk()).andReturn();

        Optional<RefreshToken> session =
                refreshTokenRepository.findByMemberIdAndDeviceId(member.getId(), DEVICE_ID);

        assertThat(session).isPresent();
        // 원문이 아니라 해시로 저장돼야 한다. DB 덤프가 새어도 그대로 제출할 수 없게.
        assertThat(session.get().getTokenHash()).isEqualTo(Sha256.hex(readString(result, "refreshToken")));
    }

    @Test
    @DisplayName("같은 기기로 다시 로그인하면 세션이 늘지 않고 토큰만 바뀐다")
    void login_rotatesSessionOnRelogin() throws Exception {
        MvcResult first = mvc.perform(loginRequest(USERNAME, PASSWORD)).andExpect(status().isOk()).andReturn();
        MvcResult second = mvc.perform(loginRequest(USERNAME, PASSWORD)).andExpect(status().isOk()).andReturn();

        String firstToken = readString(first, "refreshToken");
        String secondToken = readString(second, "refreshToken");
        assertThat(secondToken).isNotEqualTo(firstToken);

        // 기기당 세션은 하나다. 늘어나면 폰을 잃어버렸을 때 한쪽이 끊기지 않고 남는다.
        assertThat(refreshTokenRepository.count()).isEqualTo(1);

        // 회전이 실제로 저장돼야 한다. login 에 readOnly 트랜잭션이 붙으면 flush 가 일어나지 않아
        // 여기서 옛 해시가 그대로 남는다. 첫 로그인은 INSERT 라 통과하고 이 검증만 깨진다.
        RefreshToken session =
                refreshTokenRepository.findByMemberIdAndDeviceId(member.getId(), DEVICE_ID).orElseThrow();
        assertThat(session.getTokenHash()).isEqualTo(Sha256.hex(secondToken));
        assertThat(session.matches(Sha256.hex(firstToken))).isFalse();
    }

    @Test
    @DisplayName("아이디 앞뒤 공백은 오타로 보고 잘라낸다")
    void login_trimsUsername() throws Exception {
        mvc.perform(loginRequest("  " + USERNAME + "  ", PASSWORD))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("없는 아이디는 400 과 LOGIN_FAILED")
    void login_rejectsUnknownUsername() throws Exception {
        mvc.perform(loginRequest("no_such_user", PASSWORD))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("LOGIN_FAILED"));
    }

    @Test
    @DisplayName("비밀번호가 틀리면 400 과 LOGIN_FAILED")
    void login_rejectsWrongPassword() throws Exception {
        mvc.perform(loginRequest(USERNAME, "wrong-password1!"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("LOGIN_FAILED"));
    }

    @Test
    @DisplayName("검증에 걸린 입력도 검증 실패 응답이 아니라 LOGIN_FAILED 로 나간다")
    void login_absorbsValidationFailures() throws Exception {
        // 그냥 두면 errorCode 없는 검증 실패 응답이 나가 로그인 실패가 두 모양이 되고,
        // 어느 조건에 걸렸는지가 그대로 밖에 드러난다.
        for (MockHttpServletRequestBuilder request : new MockHttpServletRequestBuilder[]{
                loginRequest(TOO_LONG_USERNAME, PASSWORD),
                loginRequest("", PASSWORD),
                loginRequest(USERNAME, ""),
                loginRequest("   ", PASSWORD)}) {

            mvc.perform(request)
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.errorCode").value("LOGIN_FAILED"))
                    .andExpect(jsonPath("$.errors").doesNotExist());
        }
    }

    @Test
    @DisplayName("실패 사유가 달라도 응답이 구분되지 않는다")
    void failureResponsesAreIndistinguishable() throws Exception {
        String unknownUsername = failureBody(loginRequest("no_such_user", PASSWORD));
        String wrongPassword = failureBody(loginRequest(USERNAME, "wrong-password1!"));
        String tooLong = failureBody(loginRequest(TOO_LONG_USERNAME, PASSWORD));
        String blank = failureBody(loginRequest("", ""));

        // 이 넷이 갈리는 순간 어떤 아이디가 가입돼 있는지 밖에서 수집할 수 있게 된다.
        assertThat(wrongPassword).isEqualTo(unknownUsername);
        assertThat(tooLong).isEqualTo(unknownUsername);
        assertThat(blank).isEqualTo(unknownUsername);
    }

    @Test
    @DisplayName("탈퇴한 계정은 403 과 MEMBER_WITHDRAWN")
    void login_rejectsWithdrawnMember() throws Exception {
        // 탈퇴는 행 삭제가 아니라 상태라 비밀번호 대조 자체는 통과한다. 상태를 안 보면 그냥 로그인된다.
        member.withdraw();

        mvc.perform(loginRequest(USERNAME, PASSWORD))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("MEMBER_WITHDRAWN"));

        assertThat(refreshTokenRepository.count()).isZero();
    }

    @Test
    @DisplayName("기기 식별자가 없으면 400 이지만 로그인 실패와는 구분된다")
    void login_requiresDeviceIdHeader() throws Exception {
        // 이건 자격 증명 문제가 아니라 클라이언트 연동 실수다. LOGIN_FAILED 로 뭉뚱그리면
        // 앱 개발자가 헤더를 빠뜨린 걸 "비밀번호가 틀렸나" 로 오해한다.
        mvc.perform(post(LOGIN_PATH)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(USERNAME, PASSWORD)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").doesNotExist());
    }

    private Member saveMember() {
        Member saved = memberRepository.save(Member.builder()
                .phoneNumber(PHONE)
                .name(NAME)
                .nickname(NICKNAME)
                .build());

        loginInfoRepository.saveAndFlush(LoginInfo.builder()
                .member(saved)
                .username(USERNAME)
                .passwordHash(passwordEncoder.encode(PASSWORD))
                .build());

        return saved;
    }

    private MockHttpServletRequestBuilder loginRequest(String username, String password) {
        return post(LOGIN_PATH)
                .header(DEVICE_ID_HEADER, DEVICE_ID)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(username, password));
    }

    private String body(String username, String password) {
        return """
                {
                  "username": "%s",
                  "password": "%s"
                }
                """.formatted(username, password);
    }

    /**
     * 실패 응답에서 요청마다 달라지는 값을 걷어내고 남긴다.
     *
     * <p>{@code timestamp} 는 초 단위라 실행 시각에 따라 갈리고, {@code instance} 는 요청 경로다.
     * 둘 다 실패 사유와 무관하므로 비교에서 뺀다.
     */
    private String failureBody(MockHttpServletRequestBuilder request) throws Exception {
        String body = mvc.perform(request).andReturn().getResponse().getContentAsString();
        return body.replaceAll("\"timestamp\":\"[^\"]*\"", "");
    }

    private String readString(MvcResult result, String field) throws Exception {
        return com.jayway.jsonpath.JsonPath.read(result.getResponse().getContentAsString(), "$." + field);
    }
}
