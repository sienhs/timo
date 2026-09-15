package com.ssafy.timo.global.config;

import com.ssafy.timo.global.security.RestAccessDeniedHandler;
import com.ssafy.timo.global.security.RestAuthenticationEntryPoint;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
@EnableWebSecurity
@Profile("!local")
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http,
                                           JwtAuthenticationConverter jwtAuthenticationConverter,
                                           RestAuthenticationEntryPoint restAuthenticationEntryPoint,
                                           RestAccessDeniedHandler restAccessDeniedHandler) {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .formLogin(AbstractHttpConfigurer::disable)
                .httpBasic(AbstractHttpConfigurer::disable)
                .authorizeHttpRequests(auth -> auth
                        .requestMatchers("/actuator/health").permitAll()
                        // External ALB traffic is blocked in Terraform. The future Prometheus
                        // instance reaches this endpoint directly through its security group.
                        .requestMatchers("/actuator/prometheus").permitAll()
                        .requestMatchers(HttpMethod.POST,
                                "/api/v1/auth/sms/send",
                                "/api/v1/auth/sms/verify",
                                "/api/v1/auth/signup",
                                "/api/v1/auth/login",

                                // 부르는 시점에 access 가 이미 만료돼 있다. 인증을 걸면
                                // 재발급받으려면 재발급이 필요한 순환이 된다.
                                "/api/v1/auth/reissue",
                                "/api/v1/auth/logout").permitAll()
                        .requestMatchers(HttpMethod.GET,
                                "/api/v1/auth/availability",
                                "/api/v1/concerts",
                                "/api/v1/concerts/{concertId}",
                                "/api/v1/artists",
                                "/api/v1/artists/{artistId}").permitAll()
                        // 프론트 연동용 스텁. AuthControllerStub 가 @Profile("!prod") 라
                        // 운영에서는 이 규칙에 걸리는 핸들러 자체가 없다(404).
                        .requestMatchers("/api/v0/**").permitAll()
                        .anyRequest().authenticated()
                )
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
