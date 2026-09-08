package com.ssafy.timo.domain.auth.dto;

import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Pattern;

/**
 * 아이디·닉네임 중복 확인 요청.
 *
 * <p>엔드포인트를 하나로 두고 어느 값을 확인할지는 쿼리 파라미터로 가른다. {@code @Pattern} 은
 * null 을 통과시키므로, 하나로 받아도 필드별 형식 검사를 선언적으로 그대로 쓸 수 있다.
 * 400 응답에 어느 필드가 틀렸는지 실려 나가야 앱이 해당 입력칸에 표시할 수 있다.
 *
 * <p>둘 중 <b>정확히 하나만</b> 와야 한다. 둘 다 오면 무엇을 확인한 결과인지 알 수 없고,
 * 둘 다 없으면 확인할 대상이 없다.
 */
public record AvailabilityRequestDto(

        @Pattern(regexp = AuthPatterns.USERNAME,
                message = "아이디는 영문 소문자로 시작하는 영문, 숫자, 밑줄 4~20자입니다.")
        String username,

        @Pattern(regexp = AuthPatterns.NICKNAME,
                message = "닉네임은 한글, 영문, 숫자 2~20자입니다.")
        String nickname
) {
    // 이거 username -> 이름, nickname -> 닉네임으로 메세지 보내야하는지 의논
    @AssertTrue(message = "username 과 nickname 중 하나만 보내야 합니다.")
    public boolean isExactlyOneGiven() {
        return (username == null) != (nickname == null);
    }

    public boolean isUsernameCheck() {
        return username != null;
    }
}
