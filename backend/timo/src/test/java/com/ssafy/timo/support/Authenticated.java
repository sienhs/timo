package com.ssafy.timo.support;

import java.time.Instant;
import java.util.List;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

/**
 * 요청자를 가진 채로 MockMvc 요청을 보낸다.
 *
 * <p>{@code @CurrentMember} 의 리졸버는 {@code SecurityContextHolder} 에서 인증 객체를 읽으므로,
 * 테스트가 그것을 채워 주지 않으면 전부 401 이 된다.
 *
 * <p><b>{@code SecurityMockMvcRequestPostProcessors.jwt()} 를 쓰지 않는 이유가 있다.</b> 그쪽은
 * 인증 객체를 홀더가 아니라 <b>시큐리티 필터가 읽는 저장소</b>에 넣어 두는데,
 * {@code @IntegrationTest} 는 {@code addFilters = false} 라 그 필터가 돌지 않는다. 실제로 바꿔
 * 돌려 보면 선점 테스트가 전부 401 로 떨어진다. {@code @WithMockUser} 도 안 된다 — 그쪽 principal
 * 은 {@code Jwt} 가 아니라 {@code User} 라 리졸버가 거절한다.
 *
 * <p>홀더는 스레드에 남는다. 쓰는 테스트는 {@link #clear()} 로 정리해야 다음 테스트가 남의 신원을
 * 물려받지 않는다.
 *
 * <p>토큰은 서명하지 않는다. 필터를 타지 않아 검증될 일이 없고, 여기서 확인할 것은 <b>요청자별로
 * 동작이 갈리는지</b>지 토큰이 유효한지가 아니다. 서명·만료 판정은
 * {@code JwtAuthenticationContractTest} 와 {@code SecurityLockdownTest} 가 본다.
 */
public final class Authenticated {

    private Authenticated() {
    }

    /** 이 회원이 보낸 요청으로 만든다. */
    public static RequestPostProcessor as(long memberId) {
        return asSubject(String.valueOf(memberId));
    }

    /** {@code sub} 를 직접 정한다. 회원 id 가 아닌 값이 왔을 때를 재현할 때 쓴다. */
    public static RequestPostProcessor asSubject(String subject) {
        return request -> {
            setSubject(subject);
            return request;
        };
    }

    /** 요청 단위가 아니라 테스트 전체에 걸어 둔다. standalone MockMvc 처럼 매번 붙이기 번거로울 때. */
    public static void set(long memberId) {
        setSubject(String.valueOf(memberId));
    }

    private static void setSubject(String subject) {
        Jwt accessToken = Jwt.withTokenValue("test-token")
                .header("alg", "HS256")
                .subject(subject)
                .issuedAt(Instant.now())
                .expiresAt(Instant.now().plusSeconds(300))
                .build();

        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(new JwtAuthenticationToken(accessToken, List.of()));
        SecurityContextHolder.setContext(context);
    }

    /** 홀더를 비운다. {@code @AfterEach} 에서 부른다. */
    public static void clear() {
        SecurityContextHolder.clearContext();
    }
}
