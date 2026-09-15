package com.ssafy.timo.global.config;

import com.ssafy.timo.global.security.RestAccessDeniedHandler;
import com.ssafy.timo.global.security.RestAuthenticationEntryPoint;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

/**
 * 로컬 개발용 체인. 경로는 전부 열어 두되 토큰은 읽는다.
 *
 * <p>{@code permitAll} 은 그대로다. 프론트가 화면 하나를 붙일 때마다 그 경로를 여는 설정을
 * 기다려야 하면 개발이 멈춘다.
 *
 * <p>다만 {@code oauth2ResourceServer} 는 켠다. 좌석 선점처럼 요청자가 필요한 API 가
 * {@code @AuthenticationPrincipal} 로 토큰을 받는데, 이걸 켜지 않으면 <b>Authorization 헤더를
 * 제대로 보내도 principal 이 {@code null}</b> 이라 로컬에서만 401 이 난다. 그 차이를 디버깅하는
 * 시간이 permitAll 로 아낀 시간보다 크다.
 *
 * <p>토큰을 <b>안 보내는</b> 것과 <b>틀린 토큰을 보내는</b> 것은 다르게 다룬다. 안 보내면 익명으로
 * 통과하고(요청자가 필요한 API 에서만 401), 서명이 깨졌거나 만료된 토큰을 보내면 필터가 바로
 * 막는다. 운영과 같은 에러 응답이 나오도록 핸들러도 운영 체인과 같은 것을 쓴다.
 */
@Configuration
@Profile("local")
@EnableWebSecurity(debug = true)
public class DevSecurityConfig {

    @Bean
    SecurityFilterChain devChain(HttpSecurity http,
                                 UrlBasedCorsConfigurationSource corsConfigurationSource,
                                 JwtAuthenticationConverter jwtAuthenticationConverter,
                                 RestAuthenticationEntryPoint restAuthenticationEntryPoint,
                                 RestAccessDeniedHandler restAccessDeniedHandler) {
        http.cors(cors -> cors.configurationSource(corsConfigurationSource))
                .authorizeHttpRequests(auth -> auth.anyRequest().permitAll())
                .csrf(AbstractHttpConfigurer::disable)
                .exceptionHandling(e -> e
                        .authenticationEntryPoint(restAuthenticationEntryPoint)
                        .accessDeniedHandler(restAccessDeniedHandler)
                )
                .oauth2ResourceServer(oauth2 -> oauth2
                        .authenticationEntryPoint(restAuthenticationEntryPoint)
                        .accessDeniedHandler(restAccessDeniedHandler)
                        .jwt(jwt -> jwt.jwtAuthenticationConverter(jwtAuthenticationConverter))
                );
        return http.build();
    }
}
