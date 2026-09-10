package com.ssafy.timo.global.security;

import com.ssafy.timo.global.security.exception.TokenInvalidException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;

/**
 * 검증된 access token 에서 요청자를 꺼내는 {@link CurrentMemberProvider}.
 *
 * <p><b>요청자의 근거는 서명된 토큰의 {@code sub} 하나뿐이다.</b> 경로·본문·쿼리·헤더로 회원
 * 식별자를 받지 않는다. 클라이언트가 보낸 값을 신원으로 쓰면 그 값을 바꿔 남의 자원에
 * 접근할 수 있고, 그것을 막기 위해 "이 토큰의 주인이 이 식별자와 같은가" 를 호출마다 검사해야
 * 하는데 <b>한 곳이라도 빠뜨리면 뚫린다.</b> 받지 않으면 그 실수가 애초에 불가능하다.
 *
 * <p>{@code sub} 를 위조할 수는 없다. 토큰은 서버만 아는 대칭키로 서명돼 있어 값을 고치면
 * 서명이 깨지고 {@code JwtDecoder} 가 필터 단계에서 걸러낸다. 여기까지 온 토큰은 이미
 * 서명·만료 검증을 통과한 것이다.
 *
 * <p>인증 객체가 {@link JwtAuthenticationToken} 이 아닌 경우도 거절한다. 이 API 들은
 * {@code authenticated()} 로 잠겨 있어 정상 경로에서는 도달할 수 없지만, 설정이 풀려
 * 익명 요청이 흘러들어오면 <b>여기서 막혀야 한다.</b> 설정 실수가 곧 정보 유출이 되지 않도록
 * 두 번째 방어선을 둔다.
 */
@Slf4j
@Component
@Profile("prod | securitytest")
public class JwtCurrentMemberProvider implements CurrentMemberProvider {

    @Override
    public Long currentMemberId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

        if (!(authentication instanceof JwtAuthenticationToken jwtAuthentication)) {
            // 익명이거나 다른 인증 방식이다. 요청자를 특정할 수 없다.
            log.warn("Current member unresolved: authentication={}",
                    authentication == null ? "none" : authentication.getClass().getSimpleName());
            throw new TokenInvalidException();
        }

        String subject = jwtAuthentication.getToken().getSubject();
        try {
            return Long.parseLong(subject);
        } catch (NumberFormatException e) {
            // 우리가 발급한 토큰의 sub 는 항상 회원 id 다. 아니면 우리 토큰이 아니다.
            log.warn("Current member unresolved: sub is not a member id");
            throw new TokenInvalidException();
        }
    }
}
