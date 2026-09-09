package com.ssafy.timo.domain.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 로그인 요청.
 *
 * <p>가입과 달리 형식 검사를 하지 않는다. {@link SignupRequestDto} 처럼
 * {@code @Pattern(AuthPatterns.USERNAME)} 을 걸고 싶지만 걸면 안 된다.
 * 아이디 규칙이 나중에 바뀌면 예전 규칙으로 가입한 사람이 로그인 자체를 못하게 된다. 가입은 새 규칙으로
 * 받으면 그만이지만 로그인은 이미 있는 계정을 받아줘야 한다. 형식 위반을 400으로 돌려주는 것도
 * 어떤 형식이 유효한지 밖에다 알려주는 셈이다.
 *
 * <p>길이 상한만 둔다. {@code login_info.username} 컬럼이 50자라 그보다 긴 아이디는 저장될 수
 * 없고, 따라서 존재할 수도 없다. 조회까지 갈 이유가 없다.
 *
 * <p>다만 이 검증이 실패해도 <b>검증 실패 응답이 그대로 나가지는 않는다.</b> 그러면
 * {@code errorCode} 가 없는 응답이 나가 로그인 실패가 두 모양이 되고, 그 응답 자체가 서버가 받는
 * 상한을 밖에 알려준다. {@code AuthController} 가 {@code BindingResult} 로 받아
 * {@code LOGIN_FAILED} 하나로 흡수하므로, 밖에서 보면 아이디가 없는 경우와 구분되지 않는다.
 * 여기 적은 메시지들은 클라이언트로 나가지 않고 서버 로그에만 남는다.
 *
 * @param username 아이디. 앞뒤 공백은 오타로 보고 잘라낸다
 * @param password 비밀번호. 공백도 글자이므로 그대로 둔다
 */
public record LoginRequestDto(
        @NotBlank(message = "아이디를 입력해 주세요.")
        @Size(max = 50, message="아이디가 너무 깁니다.")
        String username,

        @NotBlank(message = "비밀번호를 입력해 주세요.")
        String password
) {

    public LoginRequestDto {
        // 검증보다 먼저 돈다. 공백만 넣은 아이디는 여기서 빈 문자열이 되어 @NotBlank 에 걸린다.
        username = username == null ? null : username.strip();
    }
}
