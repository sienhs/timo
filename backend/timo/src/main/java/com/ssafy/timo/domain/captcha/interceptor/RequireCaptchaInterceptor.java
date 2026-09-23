package com.ssafy.timo.domain.captcha.interceptor;

import com.ssafy.timo.domain.captcha.annotation.RequireCaptcha;
import com.ssafy.timo.domain.captcha.exception.CaptchaRequiredException;
import com.ssafy.timo.domain.captcha.repository.CaptchaPassedStore;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.util.Map;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.stereotype.Component;
import org.springframework.web.method.HandlerMethod;
import org.springframework.web.servlet.HandlerInterceptor;
import org.springframework.web.servlet.HandlerMapping;

/**
 * {@link RequireCaptcha} 가 붙은 핸들러에 캡차 통과 기록을 요구한다.
 *
 * <p>서블릿 필터가 아니라 {@code HandlerInterceptor} 다. 스프링 시큐리티 필터 체인은
 * {@code DispatcherServlet} 보다 앞에서 도므로, 이 인터셉터는 별도 순서 조정 없이도 인증 필터
 * 뒤에서 실행된다.
 *
 * <p>통과 여부를 <b>조회만</b> 한다. {@link CaptchaPassedStore#hasPassed} 는 지우지 않으므로, 같은
 * 공연을 여러 번 호출해도(예: 좌석 조회 반복) 매번 다시 캡차를 풀 필요가 없다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RequireCaptchaInterceptor implements HandlerInterceptor {

    private final CaptchaPassedStore captchaPassedStore;

    @Override
    public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) {
        if (!(handler instanceof HandlerMethod handlerMethod)) {
            // 정적 리소스 등 컨트롤러 메서드가 아닌 핸들러다. 애초에 애노테이션을 달 수 없다.
            return true;
        }

        RequireCaptcha requireCaptcha = handlerMethod.getMethodAnnotation(RequireCaptcha.class);
        if (requireCaptcha == null) {
            return true;
        }

        Long concertId = extractConcertId(request, requireCaptcha);
        if (concertId == null) {
            // 파라미터가 없거나 숫자가 아니다. 이 요청이 걸려야 할 곳은 캡차가 아니라 컨트롤러의
            // 파라미터 검증(400)이므로, 여기서는 막지 않고 그쪽으로 넘긴다.
            return true;
        }

        Long memberId = currentMemberId();
        if (!captchaPassedStore.hasPassed(concertId, memberId)) {
            throw new CaptchaRequiredException();
        }
        return true;
    }

    private Long extractConcertId(HttpServletRequest request, RequireCaptcha requireCaptcha) {
        String raw = switch (requireCaptcha.paramSource()) {
            case QUERY -> request.getParameter(requireCaptcha.paramName());
            case PATH_VARIABLE -> pathVariable(request, requireCaptcha.paramName());
        };
        if (raw == null || raw.isBlank()) {
            return null;
        }
        try {
            return Long.parseLong(raw.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    @SuppressWarnings("unchecked")
    private String pathVariable(HttpServletRequest request, String name) {
        Object attribute = request.getAttribute(HandlerMapping.URI_TEMPLATE_VARIABLES_ATTRIBUTE);
        if (!(attribute instanceof Map<?, ?> variables)) {
            return null;
        }
        Object value = ((Map<String, ?>) variables).get(name);
        return value == null ? null : value.toString();
    }

    /**
     * {@code CurrentMemberArgumentResolver} 와 근거가 같다 - 서명된 토큰의 {@code sub} 만 신원으로
     * 믿는다. 인터셉터는 그 리졸버(컨트롤러 인자 바인딩 전용)를 재사용할 수 없어 같은 로직을 여기
     * 따로 둔다.
     */
    private Long currentMemberId() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (!(authentication instanceof JwtAuthenticationToken jwtAuthentication)) {
            log.warn("Current member unresolved in RequireCaptchaInterceptor: authentication={}",
                    authentication == null ? "none" : authentication.getClass().getSimpleName());
            throw new TokenInvalidException();
        }

        try {
            return Long.parseLong(jwtAuthentication.getToken().getSubject());
        } catch (NumberFormatException e) {
            throw new TokenInvalidException();
        }
    }
}
