package com.ssafy.timo.domain.member;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.nimbusds.jose.JOSEObjectType;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.auth.service.AccessTokenProvider;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.entity.MemberStatus;
import com.ssafy.timo.domain.member.entity.Role;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.transaction.annotation.Transactional;

/**
 * 본인 정보 조회. <b>남의 정보가 나오지 않는다</b> 를 검증하는 것이 이 파일의 목적이다.
 *
 * <p>{@code securitytest} 프로파일을 쓴다. 다른 통합 테스트는 {@code addFilters = false} 라
 * 필터를 타지 않아 <b>인증을 검증할 수 없고</b>, {@code test} 프로파일에서는
 * {@code MockCurrentMemberProvider} 가 떠서 헤더로 신원이 정해진다. 둘 다 여기서 확인해야 할
 * 것을 건너뛰게 만든다. 이 프로파일에서는 실제 필터 체인과
 * {@code JwtCurrentMemberProvider} 가 함께 돈다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("securitytest")
@Transactional
class MemberMeApiIntegrationTest {

    private static final String PATH = "/api/v1/members/me";
    private static final String SECRET = "local-dev-only-secret-please-change-in-prod-0123456789";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private LoginInfoRepository loginInfoRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private AccessTokenProvider accessTokenProvider;

    private Member me;
    private Member other;

    @BeforeEach
    void setUp() {
        me = save("01011112222", "정희성", "티모", "timo_me");
        other = save("01033334444", "남의계정", "남티모", "timo_other");
    }

    @Test
    @DisplayName("내 토큰으로 부르면 내 정보가 나온다")
    void returnsMyInfo() throws Exception {
        mvc.perform(get(PATH).header("Authorization", "Bearer " + tokenOf(me)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.memberId").value(me.getId()))
                .andExpect(jsonPath("$.username").value("timo_me"))
                .andExpect(jsonPath("$.name").value("정희성"))
                .andExpect(jsonPath("$.nickname").value("티모"))
                .andExpect(jsonPath("$.length()").value(5));
    }

    @Test
    @DisplayName("전화번호는 가운데 네 자리가 가려진다")
    void masksPhoneNumber() throws Exception {
        mvc.perform(get(PATH).header("Authorization", "Bearer " + tokenOf(me)))
                .andExpect(jsonPath("$.phoneNumber").value("010****2222"));
    }

    @Test
    @DisplayName("개인정보 응답이라 캐시되지 않는다")
    void isNotCached() throws Exception {
        // 프록시나 브라우저 캐시에 남으면 같은 기기를 쓰는 다른 사람이 꺼내 볼 수 있다.
        mvc.perform(get(PATH).header("Authorization", "Bearer " + tokenOf(me)))
                .andExpect(header().string("Cache-Control", containsString("no-store")));
    }

    @Test
    @DisplayName("남의 토큰으로 부르면 그 사람 정보만 나오고 내 정보는 섞이지 않는다")
    void neverLeaksAnotherMember() throws Exception {
        mvc.perform(get(PATH).header("Authorization", "Bearer " + tokenOf(other)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.memberId").value(other.getId()))
                .andExpect(jsonPath("$.username").value("timo_other"))
                .andExpect(jsonPath("$.memberId").value(not(me.getId())))
                .andExpect(jsonPath("$.name").value(not("정희성")));
    }

    @Test
    @DisplayName("X-Member-Id 헤더로 남의 신원을 주장할 수 없다")
    void ignoresMemberIdHeader() throws Exception {
        // MockCurrentMemberProvider 가 쓰던 헤더다. 이 프로파일에 그 구현이 뜨면 여기서 걸린다.
        mvc.perform(get(PATH)
                        .header("Authorization", "Bearer " + tokenOf(me))
                        .header("X-Member-Id", String.valueOf(other.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.memberId").value(me.getId()));
    }

    @Test
    @DisplayName("쿼리 파라미터로도 대상을 바꿀 수 없다")
    void ignoresRequestParameters() throws Exception {
        mvc.perform(get(PATH)
                        .header("Authorization", "Bearer " + tokenOf(me))
                        .param("memberId", String.valueOf(other.getId()))
                        .param("username", "timo_other"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.memberId").value(me.getId()));
    }

    @Test
    @DisplayName("경로에 남의 식별자를 넣는 변형은 존재하지 않는다")
    void hasNoIdPath() throws Exception {
        mvc.perform(get("/api/v1/members/" + other.getId())
                        .header("Authorization", "Bearer " + tokenOf(me)))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("토큰이 없으면 401 과 TOKEN_INVALID")
    void rejectsMissingToken() throws Exception {
        mvc.perform(get(PATH))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("다른 키로 서명한 토큰은 401")
    void rejectsForgedToken() throws Exception {
        // sub 를 남의 것으로 바꿔 서명해도 우리 키가 아니면 필터에서 걸린다.
        String forged = sign("forged-secret-forged-secret-forged-secret-0123456789",
                String.valueOf(other.getId()), Duration.ofMinutes(30));

        mvc.perform(get(PATH).header("Authorization", "Bearer " + forged))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("만료된 토큰은 401 과 TOKEN_EXPIRED")
    void rejectsExpiredToken() throws Exception {
        String expired = sign(SECRET, String.valueOf(me.getId()), Duration.ofMinutes(-1));

        mvc.perform(get(PATH).header("Authorization", "Bearer " + expired))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_EXPIRED"));
    }

    @Test
    @DisplayName("sub 가 회원 id 가 아니면 401")
    void rejectsNonNumericSubject() throws Exception {
        String weird = sign(SECRET, "not-a-member-id", Duration.ofMinutes(30));

        mvc.perform(get(PATH).header("Authorization", "Bearer " + weird))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("없는 회원을 가리키는 토큰은 401")
    void rejectsTokenOfMissingMember() throws Exception {
        // 서명은 유효하지만 그 회원이 없다. 404 로 두면 앱이 재시도하며 루프에 빠진다.
        String orphan = accessTokenProvider.issue(999_999_999L, Role.USER).value();

        mvc.perform(get(PATH).header("Authorization", "Bearer " + orphan))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("탈퇴한 회원은 남은 토큰으로도 조회하지 못한다")
    void rejectsWithdrawnMember() throws Exception {
        // 탈퇴는 행을 지우지 않고 상태만 바꾼다. access 토큰은 최대 30분 더 유효하다.
        me.withdraw();
        memberRepository.saveAndFlush(me);

        mvc.perform(get(PATH).header("Authorization", "Bearer " + tokenOf(me)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("MEMBER_WITHDRAWN"));
    }

    @Test
    @DisplayName("정지된 회원도 조회하지 못한다")
    void rejectsSuspendedMember() throws Exception {
        ReflectionTestUtils.setField(me, "status", MemberStatus.SUSPENDED);
        memberRepository.saveAndFlush(me);

        mvc.perform(get(PATH).header("Authorization", "Bearer " + tokenOf(me)))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.errorCode").value("MEMBER_SUSPENDED"));
    }

    private Member save(String phoneNumber, String name, String nickname, String username) {
        Member saved = memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber)
                .name(name)
                .nickname(nickname)
                .build());

        loginInfoRepository.saveAndFlush(LoginInfo.builder()
                .member(saved)
                .username(username)
                .passwordHash(passwordEncoder.encode("timo1234!"))
                .build());

        return saved;
    }

    private String tokenOf(Member member) {
        return accessTokenProvider.issue(member.getId(), member.getRole()).value();
    }

    private String sign(String secret, String subject, Duration validFor) throws Exception {
        Instant now = Instant.now();
        SignedJWT jwt = new SignedJWT(
                new JWSHeader.Builder(JWSAlgorithm.HS256).type(JOSEObjectType.JWT).build(),
                new JWTClaimsSet.Builder()
                        .subject(subject)
                        .claim("roles", List.of(Role.USER.name()))
                        .issueTime(Date.from(now.minus(Duration.ofMinutes(2))))
                        .expirationTime(Date.from(now.plus(validFor)))
                        .build());
        jwt.sign(new MACSigner(secret.getBytes(StandardCharsets.UTF_8)));
        return jwt.serialize();
    }
}
