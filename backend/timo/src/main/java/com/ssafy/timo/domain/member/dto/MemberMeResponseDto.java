package com.ssafy.timo.domain.member.dto;

import com.ssafy.timo.global.util.Masked;

/**
 * 본인 정보 조회 결과.
 *
 * <p>대상은 요청 값이 아니라 <b>access token 의 {@code sub}</b> 로 정해진다. 그래서 이 응답에는
 * 언제나 요청자 자신의 정보만 담긴다.
 *
 * @param memberId    회원 식별자
 * @param username    로그인 아이디
 * @param name        본인인증으로 확인된 실명
 * @param nickname    서비스에 노출되는 이름
 * @param phoneNumber 가운데 네 자리를 가린 번호.
 */
public record MemberMeResponseDto(
        Long memberId,
        String username,
        String name,
        String nickname,
        String phoneNumber
) {

    /** 실명과 번호가 로그로 새지 않게 가린다. */
    @Override
    public String toString() {
        return "MemberMeResponseDto[memberId=%s, username=%s, name=%s, nickname=%s, phoneNumber=%s]"
                .formatted(memberId, username, Masked.of(name), nickname, Masked.of(phoneNumber));
    }
}
