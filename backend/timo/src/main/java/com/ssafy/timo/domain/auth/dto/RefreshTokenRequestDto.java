package com.ssafy.timo.domain.auth.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * refresh 토큰 하나만 받는 요청. 재발급과 로그아웃이 같이 쓴다.
 *
 * <p>둘로 나누지 않은 이유는 입력이 정말로 같기 때문이다. 한 필드짜리 record 를 두 벌 두면
 * 한쪽만 고쳐지는 일이 생긴다. 나중에 어느 한쪽에 필드가 붙으면 그때 갈라낸다.
 *
 * <p>여기서 걸린 검증은 <b>클라이언트에 그대로 나가지 않는다.</b> 재발급은 토큰 문제와 같은
 * {@code TOKEN_INVALID} 로, 로그아웃은 그냥 성공으로 흡수한다. 자세한 이유는 {@code AuthController} 참고.
 *
 * @param refreshToken 로그인·가입 때 받은 값. 서버에는 해시만 있어 원문 대조는 이 값으로만 가능하다
 */
public record RefreshTokenRequestDto(

        @NotBlank(message = "인증 정보가 필요합니다.")
        String refreshToken
) {
}
