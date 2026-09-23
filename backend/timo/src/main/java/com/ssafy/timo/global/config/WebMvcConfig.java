package com.ssafy.timo.global.config;

import com.ssafy.timo.domain.captcha.interceptor.RequireCaptchaInterceptor;
import com.ssafy.timo.global.security.CurrentMember;
import com.ssafy.timo.global.security.CurrentMemberArgumentResolver;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.method.support.HandlerMethodArgumentResolver;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * 컨트롤러 파라미터 확장과 인터셉터 등록.
 *
 * <p>{@link CurrentMember} 를 채우는 리졸버를 등록한다. 등록하지 않으면 스프링이 그 파라미터를
 * {@code @ModelAttribute} 로 보고 바인딩을 시도하는데, 조용히 이상한 값이 들어오는 게 아니라
 * 그 엔드포인트가 통째로 500 이 되므로 빠뜨리면 바로 드러난다.
 *
 * <p>{@code WebMvcConfigurer} 를 구현해도 스프링 부트의 MVC 자동 구성은 그대로 살아 있다.
 * {@code @EnableWebMvc} 를 붙이면 그게 꺼지므로 붙이지 않는다.
 */
@Configuration
@RequiredArgsConstructor
public class WebMvcConfig implements WebMvcConfigurer {

    private final RequireCaptchaInterceptor requireCaptchaInterceptor;

    @Override
    public void addArgumentResolvers(List<HandlerMethodArgumentResolver> resolvers) {
        resolvers.add(new CurrentMemberArgumentResolver());
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(requireCaptchaInterceptor);
    }
}
