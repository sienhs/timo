package com.ssafy.timo.global.security;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.global.security.exception.ForbiddenException;
import com.ssafy.timo.global.security.exception.TokenExpiredException;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;

/**
 * 인증 실패 응답의 모양을 못 박는다.
 *
 * <p>앱이 만료와 무효를 가르는 근거가 {@code errorCode} 다. 이 값이 빠지거나 이름이 바뀌면
 * 앱은 만료된 토큰에도 재발급 대신 로그아웃하거나, 반대로 못 고칠 토큰으로 재발급을 반복한다.
 * 그래서 필드 존재 여부와 값을 함께 고정한다.
 *
 * <p>MockMvc 로 실제 응답까지 확인하지 못하는 이유는 통합 테스트가 보안 필터를 타지 않기 때문이다
 * (CLAUDE.md 4-1). 그 제약이 풀리면 실제 401 응답 본문까지 검증하는 편이 낫다.
 * advice 우선순위가 실제로 먹는지는 2026-09-08 에 실제 요청으로 확인했다.
 */
class AuthExceptionHandlerTest {

    private final AuthExceptionHandler authExceptionHandler = new AuthExceptionHandler();

    @Test
    @DisplayName("만료는 TOKEN_EXPIRED 로 나간다")
    void expired() {
        ProblemDetail problemDetail = authExceptionHandler.handleAuthException(new TokenExpiredException());

        assertThat(problemDetail.getStatus()).isEqualTo(HttpStatus.UNAUTHORIZED.value());
        assertThat(problemDetail.getProperties()).containsEntry("errorCode", "TOKEN_EXPIRED");
    }

    @Test
    @DisplayName("무효한 토큰은 TOKEN_INVALID 로 나간다")
    void invalid() {
        ProblemDetail problemDetail = authExceptionHandler.handleAuthException(new TokenInvalidException());

        assertThat(problemDetail.getStatus()).isEqualTo(HttpStatus.UNAUTHORIZED.value());
        assertThat(problemDetail.getProperties()).containsEntry("errorCode", "TOKEN_INVALID");
    }

    @Test
    @DisplayName("권한 부족은 403 FORBIDDEN 으로 나간다")
    void forbidden() {
        ProblemDetail problemDetail = authExceptionHandler.handleAuthException(new ForbiddenException());

        assertThat(problemDetail.getStatus()).isEqualTo(HttpStatus.FORBIDDEN.value());
        assertThat(problemDetail.getProperties()).containsEntry("errorCode", "FORBIDDEN");
    }

    @Test
    @DisplayName("GlobalExceptionHandler 와 같은 필드 구성을 유지한다")
    void keepsSharedProblemDetailShape() {
        ProblemDetail problemDetail = authExceptionHandler.handleAuthException(new TokenExpiredException());

        // errorCode 하나만 더 얹고 나머지는 다른 도메인 응답과 같아야 한다.
        // 여기가 갈라지면 앱이 경로마다 다른 파싱을 하게 된다.
        assertThat(problemDetail.getProperties())
                .containsOnlyKeys("errorCode", "errorMessage", "timestamp", "exception");
        assertThat(problemDetail.getType()).hasToString("about:blank");
        assertThat(problemDetail.getDetail()).isNull();
        assertThat(problemDetail.getProperties())
                .containsEntry("exception", "TokenExpiredException")
                .containsEntry("errorMessage", "인증이 만료되었습니다.");
    }
}
