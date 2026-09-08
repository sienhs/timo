package com.ssafy.timo.global.security;

/**
 * 지금 요청을 보낸 회원이 누구인지 알려주는 포트.
 *
 * <p>도메인은 "요청자가 누구인지"만 알면 되고, 그것을 JWT 에서 꺼내는지 헤더에서 꺼내는지는
 * 이 인터페이스 뒤로 숨긴다. 인증이 붙으면 구현체만 갈아 끼우면 되고, 이 포트를 쓰는
 * 서비스·컨트롤러는 손대지 않는다.
 *
 * <p>요청 본문으로 회원 id 를 받지 않는 이유가 여기에 있다. 본문에 넣으면 인증이 붙는 순간
 * API 규약이 바뀌지만, 포트로 두면 지금 정한 규약이 그대로 최종본이다.
 */
public interface CurrentMemberProvider {

    /**
     * 요청자의 회원 id.
     *
     * @throws com.ssafy.timo.global.security.exception.TokenInvalidException 요청자를 특정할 수 없는 경우
     */
    Long currentMemberId();
}
