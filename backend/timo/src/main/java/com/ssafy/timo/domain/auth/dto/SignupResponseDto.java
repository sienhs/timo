package com.ssafy.timo.domain.auth.dto;

import com.ssafy.timo.global.util.Masked;
/**
 * 회원가입 결과. 가입과 동시에 로그인 상태가 되도록 토큰을 함께 내려준다.
 *
 * @param memberId              가입된 회원 식별자
 * @param accessToken           API 호출에 쓰는 JWT
 * @param refreshToken          access 가 만료됐을 때 재발급에 쓰는 값. JWT 가 아닌 난수다
 * @param accessTokenExpiresIn  access 의 남은 수명(초). 앱이 만료 직전에 미리 재발급할 수 있게 준다
 */
public record SignupResponseDto(
        Long memberId,
        String accessToken,
        String refreshToken,
        long accessTokenExpiresIn
) {

    @Override
    public String toString() {
        return "SignupResponseDto[memberId=%s, accessToken=%s, refreshToken=%s, accessTokenExpiresIn=%d]"
                .formatted(memberId, Masked.of(accessToken), Masked.of(refreshToken), accessTokenExpiresIn);
    }
}
