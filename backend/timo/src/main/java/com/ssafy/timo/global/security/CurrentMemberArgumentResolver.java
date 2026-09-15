package com.ssafy.timo.global.security;

import com.ssafy.timo.global.security.exception.TokenInvalidException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.MethodParameter;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.support.WebDataBinderFactory;
import org.springframework.web.context.request.NativeWebRequest;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.method.support.ModelAndViewContainer;

/**
 * {@link CurrentMember} 를 access token 의 {@code sub} 로 채운다.
 *
 * <p>{@code sub} 를 위조할 수는 없다. 토큰은 서버만 아는 대칭키로 서명돼 있어 값을 고치면 서명이
 * 깨지고 {@code JwtDecoder} 가 필터 단계에서 걸러낸다. 여기까지 온 토큰은 이미 서명·만료 검증을
 * 통과한 것이다.
 *
 * <p>인증 객체가 {@link JwtAuthenticationToken} 이 아니면 거절한다. 익명도, 다른 인증 방식도,
 * 아예 없는 것도 전부 "요청자를 특정할 수 없음" 이다. 운영({@code SecurityConfig})에서는 보호된
 * 경로가 {@code authenticated()} 로 잠겨 있어 여기까지 익명 요청이 오지 않지만,
 * {@code local} 처럼 {@code permitAll} 인 체인에서는 토큰 없이 도달할 수 있다.
 * <b>설정이 느슨해지는 것이 곧 정보 유출이 되지 않도록</b> 두 번째 방어선을 둔다.
 *
 * <p>회원이 실제로 존재하는지는 확인하지 않는다. 그건 도메인의 몫이고, 여기서 조회하면 요청마다
 * 쓰지도 않을 SELECT 가 한 번씩 더 나간다.
 */
@Slf4j
public class CurrentMemberArgumentResolver implements HandlerMethodArgumentResolver {

    @Override
    public boolean supportsParameter(MethodParameter parameter) {
        return parameter.hasParameterAnnotation(CurrentMember.class)
                && Long.class.isAssignableFrom(parameter.getParameterType());
    }

    @Override
    public Long resolveArgument(MethodParameter parameter,
                                ModelAndViewContainer mavContainer,
                                NativeWebRequest webRequest,
                                WebDataBinderFactory binderFactory) {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();

        if (!(authentication instanceof JwtAuthenticationToken jwtAuthentication)) {
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
