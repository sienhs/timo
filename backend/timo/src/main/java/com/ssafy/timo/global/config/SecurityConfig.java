package com.ssafy.timo.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.cors.CorsConfigurationSource;

@Configuration
@EnableWebSecurity(debug = true)
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http, CorsConfigurationSource corsConfigurationSource) {
        http
                .cors(cors -> cors.configurationSource(corsConfigurationSource))
                // JWT의 sessionless -> CSRF 비활성화
                .csrf(AbstractHttpConfigurer::disable)
                // RESTAPI+JWT를 사용할땐 폼 로그인 방식을 사용하지 않는다.
                .formLogin(AbstractHttpConfigurer::disable)
                // Basic인증은 author: Basic base64(id:pw) 헤더 방식인데 JWT 사용하면 필요 없다.
                .httpBasic(AbstractHttpConfigurer::disable)
                // 세션 비활성화
                // JWT는 stateless라서 세션을 만들지도 사용하지도 않는다.
                .sessionManagement(session-> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

                // 요청별 접근 권한 설정
                .authorizeHttpRequests(auth -> auth
                        // 로그인 회원가입은 토큰 없이 누구나 가능하게 끔
                        .requestMatchers("/api/auth/**").permitAll()

                        // 요청 매핑 필요
                        .anyRequest().authenticated());
        return http.build();
    }

}
