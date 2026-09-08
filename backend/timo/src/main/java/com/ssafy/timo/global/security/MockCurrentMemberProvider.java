package com.ssafy.timo.global.security;

import com.ssafy.timo.global.security.exception.TokenInvalidException;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * 인증 연동 전까지 쓰는 임시 {@link CurrentMemberProvider}.
 *
 * <p>{@code X-Member-Id} 요청 헤더를 그대로 요청자로 받아들인다. <b>클라이언트가 보낸 값을 검증
 * 없이 믿는다</b>는 뜻이라, 이 구현이 운영에 올라가면 아무나 남의 계정으로 행세할 수 있다.
 * 그래서 {@code prod} 프로필에서는 등록되지 않고, 대신 {@link DeniedCurrentMemberProvider} 가
 * 올라가 401 로 막는다.
 *
 * <p>회원이 실제로 존재하는지 확인하지 않는다. 회원 조회는 인증 구현체의 책임이고, 여기서
 * 흉내 내면 갈아 끼울 때 지워야 할 코드만 늘어난다.
 *
 * <p><b>TODO</b>: JWT 인증이 붙으면 인증 주체에서 회원 id 를 꺼내는 구현체로 교체하고
 * 이 클래스와 {@link DeniedCurrentMemberProvider} 를 삭제한다.
 */
@Component
@Profile("!prod")
@RequiredArgsConstructor
public class MockCurrentMemberProvider implements CurrentMemberProvider {

    static final String MEMBER_ID_HEADER = "X-Member-Id";

    /** 싱글턴에 주입해도 요청마다 현재 요청으로 연결되는 프록시가 들어온다. */
    private final HttpServletRequest request;

    @Override
    public Long currentMemberId() {
        String raw = request.getHeader(MEMBER_ID_HEADER);
        if (raw == null || raw.isBlank()) {
            throw new TokenInvalidException();
        }

        try {
            return Long.parseLong(raw.trim());
        } catch (NumberFormatException e) {
            // 헤더가 깨진 것은 인증 정보가 올바르지 않은 것과 같게 다룬다.
            throw new TokenInvalidException();
        }
    }
}
