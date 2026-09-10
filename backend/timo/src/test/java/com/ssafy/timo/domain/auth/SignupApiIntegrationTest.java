package com.ssafy.timo.domain.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.auth.repository.RefreshTokenRepository;
import com.ssafy.timo.domain.auth.repository.SmsVerificationStore;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.entity.MemberStatus;
import com.ssafy.timo.domain.member.entity.Role;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.wallet.entity.Wallet;
import com.ssafy.timo.domain.wallet.repository.WalletRepository;
import com.ssafy.timo.global.util.Sha256;
import com.ssafy.timo.support.IntegrationTest;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * 회원가입 API 통합 테스트.
 *
 * <p>컨트롤러부터 서비스, JPA, 실제 MySQL 까지 그대로 태운다. 검증 티켓은 인증 단계가 남기는
 * 값이므로 저장소에 직접 넣어 준비한다.
 *
 * <p><b>주의</b>: {@code IntegrationTest} 가 {@code addFilters = false} 라 시큐리티 필터를 타지 않는다.
 * 따라서 이 테스트는 <b>가입 경로가 permitAll 로 열려 있는지 검증하지 못한다.</b>
 * 필터를 태우는 테스트를 붙일 수 있게 되면 그 확인을 따로 추가해야 한다.
 */
@IntegrationTest
class SignupApiIntegrationTest {

    private static final String SIGNUP_PATH = "/api/v1/auth/signup";
    private static final String DEVICE_ID_HEADER = "X-Device-Id";
    private static final String DEVICE_ID = "11111111-1111-1111-1111-111111111111";

    private static final String PHONE = "01012345678";
    private static final String NAME = "정희성";
    private static final String USERNAME = "timo_user";
    private static final String PASSWORD = "timo1234!";
    private static final String NICKNAME = "티모";

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
    private WalletRepository walletRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private JwtDecoder jwtDecoder;

    @Test
    @DisplayName("가입하면 201 과 함께 회원 식별자와 토큰을 반환한다")
    void signUp_returnsCreatedWithTokens() throws Exception {
        String ticket = issueTicket(PHONE);

        MvcResult result = mvc.perform(signupRequest(ticket, PHONE, USERNAME, NICKNAME))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.memberId").isNumber())
                .andExpect(jsonPath("$.accessToken").isString())
                .andExpect(jsonPath("$.refreshToken").isString())
                .andExpect(jsonPath("$.accessTokenExpiresIn").isNumber())
                .andReturn();

        // 가입과 동시에 로그인 상태가 되어야 한다. 토큰이 실제로 우리 디코더로 풀려야 의미가 있다.
        Jwt jwt = jwtDecoder.decode(readString(result, "accessToken"));
        assertThat(jwt.getSubject()).isEqualTo(String.valueOf(readNumber(result, "memberId")));
        assertThat(jwt.getClaimAsStringList("roles")).containsExactly(Role.USER.name());
    }

    @Test
    @DisplayName("가입하면 회원·로그인 수단·세션이 모두 저장된다")
    void signUp_persistsMemberLoginInfoAndSession() throws Exception {
        String ticket = issueTicket(PHONE);

        mvc.perform(signupRequest(ticket, PHONE, USERNAME, NICKNAME)).andExpect(status().isCreated());

        Member member = memberRepository.findAll().getFirst();
        assertThat(member.getPhoneNumber()).isEqualTo(PHONE);
        assertThat(member.getNickname()).isEqualTo(NICKNAME);
        assertThat(member.getRole()).isEqualTo(Role.USER);
        assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);

        assertThat(loginInfoRepository.existsByUsername(USERNAME)).isTrue();
        assertThat(refreshTokenRepository.findByMemberIdAndDeviceId(member.getId(), DEVICE_ID)).isPresent();
    }

    @Test
    @DisplayName("가입하면 지갑도 함께 생성된다")
    void signUp_createsWallet() throws Exception {
        String ticket = issueTicket(PHONE);

        mvc.perform(signupRequest(ticket, PHONE, USERNAME, NICKNAME)).andExpect(status().isCreated());

        Member member = memberRepository.findAll().getFirst();
        Wallet wallet = walletRepository.findById(member.getId()).orElseThrow();
        // 대소문자를 섞지 않고 항상 소문자로 고정한다 - CustodialWalletCrypto 주석 참고.
        assertThat(wallet.getAddress()).matches("^0x[0-9a-f]{40}$");
        assertThat(wallet.getEncryptedKeystoreJson()).isNotBlank();
        assertThat(wallet.getWrappedDek()).isNotBlank();
    }

    @Test
    @DisplayName("비밀번호는 평문이 아니라 해시로 저장된다")
    void signUp_storesHashedPassword() throws Exception {
        String ticket = issueTicket(PHONE);

        mvc.perform(signupRequest(ticket, PHONE, USERNAME, NICKNAME)).andExpect(status().isCreated());

        String passwordHash = loginInfoRepository.findAll().getFirst().getPasswordHash();
        assertThat(passwordHash).isNotEqualTo(PASSWORD);
        assertThat(passwordEncoder.matches(PASSWORD, passwordHash)).isTrue();
    }

    @Test
    @DisplayName("검증 티켓은 1회용이라 같은 티켓으로 두 번 가입할 수 없다")
    void signUp_consumesTicket() throws Exception {
        String ticket = issueTicket(PHONE);

        mvc.perform(signupRequest(ticket, PHONE, USERNAME, NICKNAME)).andExpect(status().isCreated());

        mvc.perform(signupRequest(ticket, PHONE, "other_user", "다른닉네임"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("VerificationTicketInvalidException"));
    }

    @Test
    @DisplayName("티켓이 없으면 가입할 수 없다")
    void signUp_rejectsUnknownTicket() throws Exception {
        mvc.perform(signupRequest("never-issued-ticket", PHONE, USERNAME, NICKNAME))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value("본인인증이 만료되었습니다. 다시 인증해 주세요."));

        assertThat(memberRepository.count()).isZero();
    }

    @Test
    @DisplayName("티켓에 묶인 번호와 다른 번호로는 가입할 수 없다")
    void signUp_rejectsPhoneNumberMismatch() throws Exception {
        // 자기 번호로 받은 티켓에 남의 번호를 실어 보내는 경우.
        String ticket = issueTicket(PHONE);

        mvc.perform(signupRequest(ticket, "01099998888", USERNAME, NICKNAME))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("VerificationTicketInvalidException"));

        assertThat(memberRepository.count()).isZero();
    }

    @Test
    @DisplayName("이미 가입된 번호면 409 를 반환한다")
    void signUp_rejectsDuplicatePhoneNumber() throws Exception {
        mvc.perform(signupRequest(issueTicket(PHONE), PHONE, USERNAME, NICKNAME))
                .andExpect(status().isCreated());

        mvc.perform(signupRequest(issueTicket(PHONE), PHONE, "other_user", "다른닉네임"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage").value("이미 가입된 전화번호입니다."));
    }

    @Test
    @DisplayName("이미 쓰는 아이디면 409 를 반환한다")
    void signUp_rejectsDuplicateUsername() throws Exception {
        mvc.perform(signupRequest(issueTicket(PHONE), PHONE, USERNAME, NICKNAME))
                .andExpect(status().isCreated());

        mvc.perform(signupRequest(issueTicket("01099998888"), "01099998888", USERNAME, "다른닉네임"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage").value("이미 사용 중인 아이디입니다."));
    }

    @Test
    @DisplayName("이미 쓰는 닉네임이면 409 를 반환한다")
    void signUp_rejectsDuplicateNickname() throws Exception {
        mvc.perform(signupRequest(issueTicket(PHONE), PHONE, USERNAME, NICKNAME))
                .andExpect(status().isCreated());

        mvc.perform(signupRequest(issueTicket("01099998888"), "01099998888", "other_user", NICKNAME))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.errorMessage").value("이미 사용 중인 닉네임입니다."));
    }

    @Test
    @DisplayName("기기 식별자 헤더가 없으면 400 을 반환한다")
    void signUp_requiresDeviceIdHeader() throws Exception {
        String ticket = issueTicket(PHONE);

        mvc.perform(post(SIGNUP_PATH)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(ticket, PHONE, USERNAME, NICKNAME)))
                .andExpect(status().isBadRequest());

        assertThat(memberRepository.count()).isZero();
    }

    @Test
    @DisplayName("형식에 맞지 않는 입력은 어느 필드가 왜 틀렸는지 알려준다")
    void signUp_reportsInvalidFields() throws Exception {
        String ticket = issueTicket(PHONE);

        // 아이디가 숫자로 시작하고, 비밀번호에 특수문자가 없다.
        mvc.perform(post(SIGNUP_PATH)
                        .header(DEVICE_ID_HEADER, DEVICE_ID)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "verificationTicket": "%s",
                                  "phoneNumber": "%s",
                                  "name": "%s",
                                  "username": "1abc",
                                  "password": "timo12345",
                                  "nickname": "%s"
                                }
                                """.formatted(ticket, PHONE, NAME, NICKNAME)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[*].field").value(org.hamcrest.Matchers.hasItem("username")));

        assertThat(memberRepository.count()).isZero();
    }

    /** 인증 단계가 남기는 티켓을 직접 넣어 준비한다. */
    private String issueTicket(String phoneNumber) {
        String ticket = UUID.randomUUID().toString();
        smsVerificationStore.saveTicket(Sha256.hex(ticket), phoneNumber, Duration.ofMinutes(30));
        return ticket;
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder signupRequest(
            String ticket, String phoneNumber, String username, String nickname) {
        return post(SIGNUP_PATH)
                .header(DEVICE_ID_HEADER, DEVICE_ID)
                .contentType(MediaType.APPLICATION_JSON)
                .content(body(ticket, phoneNumber, username, nickname));
    }

    private String body(String ticket, String phoneNumber, String username, String nickname) {
        return """
                {
                  "verificationTicket": "%s",
                  "phoneNumber": "%s",
                  "name": "%s",
                  "username": "%s",
                  "password": "%s",
                  "nickname": "%s"
                }
                """.formatted(ticket, phoneNumber, NAME, username, PASSWORD, nickname);
    }

    private String readString(MvcResult result, String field) throws Exception {
        return com.jayway.jsonpath.JsonPath.read(result.getResponse().getContentAsString(), "$." + field);
    }

    private Number readNumber(MvcResult result, String field) throws Exception {
        return com.jayway.jsonpath.JsonPath.read(result.getResponse().getContentAsString(), "$." + field);
    }
}
