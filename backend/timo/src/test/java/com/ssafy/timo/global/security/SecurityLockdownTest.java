package com.ssafy.timo.global.security;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.nimbusds.jose.JOSEObjectType;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.MACSigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import com.ssafy.timo.domain.auth.service.AccessTokenProvider;
import com.ssafy.timo.domain.member.entity.Role;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 보호된 경로가 실제로 잠겨 있는지 검증한다.
 *
 * <p>다른 통합 테스트는 {@code addFilters = false} 로 필터를 빼기 때문에 인가를 확인할 수 없다.
 * 여기서만 <b>필터 체인을 그대로 태운다.</b> 그래서 {@code securitytest} 라는 별도 프로파일을 쓴다
 * ({@code SecurityConfig} 가 {@code @Profile("!local & !test")} 라 test 프로파일에서는 뜨지 않는다).
 *
 * <p>이 테스트가 막는 사고는 하나다. permitAll 목록에 새 공개 경로를 넣는 걸 깜빡하면
 * 다른 테스트는 전부 통과하고 <b>배포 후에야 401 이 난다.</b>
 *
 * <p>컨텍스트가 하나 더 뜨는 비용을 감수한 것이다. 인가는 다른 방법으로 검증할 수 없다.
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("securitytest")
class SecurityLockdownTest {

    private static final String SECRET = "local-dev-only-secret-please-change-in-prod-0123456789";
    private static final String PROTECTED_PATH = "/api/v1/concerts/1";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private AccessTokenProvider accessTokenProvider;

    @Test
    @DisplayName("가입 흐름 세 경로는 토큰 없이 열려 있다")
    void signupFlowIsPublic() throws Exception {
        // 401 이 아니라 비즈니스 응답이 나오면 필터를 통과한 것이다.
        mvc.perform(post("/api/v1/auth/signup")
                        .header("X-Device-Id", "device")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"verificationTicket":"none","phoneNumber":"01012345678","name":"정희성",
                                 "username":"timouser","password":"timo1234!","nickname":"티모"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("VerificationTicketInvalidException"));

        mvc.perform(post("/api/v1/auth/sms/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"phoneNumber":"01012345678","code":"000000"}"""))
                .andExpect(status().isBadRequest());

        mvc.perform(get("/api/v1/auth/availability").param("username", "timouser"))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("로그인은 토큰 없이 열려 있고, 실패해도 401 이 아니다")
    void loginIsPublic() throws Exception {
        // 401 로 나가면 앱의 "401 이면 재발급" 처리가 로그인 실패에 끼어든다.
        mvc.perform(post("/api/v1/auth/login")
                        .header("X-Device-Id", "device")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"username":"nosuchuser","password":"timo1234!"}"""))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorCode").value("LOGIN_FAILED"));
    }

    @Test
    @DisplayName("재발급은 토큰 없이 열려 있다")
    void reissueIsPublic() throws Exception {
        // 부르는 시점에 access 가 이미 만료돼 있다. 잠기면 재발급받으려면 재발급이 필요해진다.
        mvc.perform(post("/api/v1/auth/reissue")
                        .header("X-Device-Id", "device")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"never-issued-token"}"""))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("로그아웃은 토큰 없이 열려 있다")
    void logoutIsPublic() throws Exception {
        // 재발급과 같은 이유다. access 가 만료된 뒤에도 로그아웃은 되어야 한다.
        mvc.perform(post("/api/v1/auth/logout")
                        .header("X-Device-Id", "device")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"refreshToken":"never-issued-token"}"""))
                .andExpect(status().isNoContent());
    }

    @Test
    @DisplayName("헬스체크와 내부 수집용 Prometheus 메트릭 endpoint는 필터를 통과한다")
    void actuatorAllowsHealthAndPrometheusForInternalCollector() throws Exception {
        // Prometheus의 외부 접근은 ALB 경로 차단 및 EC2 보안 그룹이 담당한다.
        mvc.perform(get("/actuator/health")).andExpect(status().isOk());
        mvc.perform(get("/actuator/prometheus")).andExpect(status().isOk());

        // develop 의 재작성에서 빠졌던 확인이다. env 는 설정값을 그대로 뱉으므로 잠겨 있어야 한다.
        mvc.perform(get("/actuator/env")).andExpect(status().isUnauthorized());
    }

    @Test
    @DisplayName("토큰이 없으면 401 과 TOKEN_INVALID")
    void noToken() throws Exception {
        mvc.perform(get(PROTECTED_PATH))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("서명이 다른 토큰은 401 과 TOKEN_INVALID")
    void forgedToken() throws Exception {
        String forged = token(Duration.ofMinutes(30), "another-secret-key-that-is-long-enough-0123456789");

        mvc.perform(get(PROTECTED_PATH).header("Authorization", "Bearer " + forged))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_INVALID"));
    }

    @Test
    @DisplayName("만료된 토큰은 401 과 TOKEN_EXPIRED")
    void expiredToken() throws Exception {
        // TOKEN_INVALID 로 나가면 앱이 재발급 없이 로그아웃한다. 둘의 구분이 여기서 갈린다.
        String expired = token(Duration.ofMinutes(-30), SECRET);

        mvc.perform(get(PROTECTED_PATH).header("Authorization", "Bearer " + expired))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.errorCode").value("TOKEN_EXPIRED"));
    }

    @Test
    @DisplayName("유효한 토큰은 필터를 통과해 컨트롤러까지 간다")
    void validToken() throws Exception {
        String issued = accessTokenProvider.issue(1L, Role.USER).value();

        // 공연이 없으므로 404 다. 401 이 아니라는 것이 확인 대상이다.
        mvc.perform(get(PROTECTED_PATH).header("Authorization", "Bearer " + issued))
                .andExpect(status().isNotFound());
    }

    private String token(Duration validFor, String secret) throws Exception {
        JWTClaimsSet claims = new JWTClaimsSet.Builder()
                .subject("1")
                .claim("roles", List.of(Role.USER.name()))
                .issueTime(Date.from(Instant.now().minus(Duration.ofHours(1))))
                .expirationTime(Date.from(Instant.now().plus(validFor)))
                .build();

        SignedJWT jwt = new SignedJWT(
                new JWSHeader.Builder(JWSAlgorithm.HS256).type(JOSEObjectType.JWT).build(), claims);
        jwt.sign(new MACSigner(secret.getBytes(StandardCharsets.UTF_8)));

        return jwt.serialize();
    }
}
