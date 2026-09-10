package com.ssafy.timo.domain.auth.dto;

import com.ssafy.timo.global.util.Masked;
/**
 * 로그인 결과.
 *
 * <p>{@link SignupResponseDto} 와 필드가 같다. 앱이 가입 직후와 로그인 직후에 해야 할 일
 * (토큰 저장 → 홈으로 이동)이 완전히 같기 때문이다. 한쪽만 필드를 늘리면 그 처리도 갈라진다.
 *
 * @param memberId             로그인한 회원 식별자
 * @param accessToken          API 호출에 쓰는 JWT
 * @param refreshToken         access 가 만료됐을 때 재발급에 쓰는 값. JWT 가 아닌 난수다
 * @param accessTokenExpiresIn access 의 남은 수명(초). 앱이 만료 직전에 미리 재발급할 수 있게 준다
 */
public record LoginResponseDto(
        Long memberId,
        String accessToken,
        String refreshToken,
        long accessTokenExpiresIn
) {

    @Override
    public String toString() {
        return "LoginResponseDto[memberId=%s, accessToken=%s, refreshToken=%s, accessTokenExpiresIn=%d]"
                .formatted(memberId, Masked.of(accessToken), Masked.of(refreshToken), accessTokenExpiresIn);
    }
}
