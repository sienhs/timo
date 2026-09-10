package com.ssafy.timo.domain.auth.dto;

/**
 * access 토큰 재발급 결과.
 *
 * <p>{@link LoginResponseDto} 와 달리 {@code refreshToken} 이 없다. 재발급은 refresh 를 회전시키지
 * 않고 그대로 두기 때문이다. 앱은 갖고 있던 refresh 를 계속 쓰면 된다.
 *
 * <p>{@code memberId} 도 없다. 재발급을 부르는 시점의 앱은 이미 로그인 상태라 알고 있다.
 *
 * @param accessToken          새로 발급된 JWT
 * @param accessTokenExpiresIn 남은 수명(초). 앱이 만료 직전에 미리 재발급할 수 있게 준다
 */
public record ReissueResponseDto(
        String accessToken,
        long accessTokenExpiresIn
) {
}
