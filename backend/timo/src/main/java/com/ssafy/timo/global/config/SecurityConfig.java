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

                        // Public endpoints
                        .requestMatchers("/actuator/health").permitAll()
                        .requestMatchers("/actuator/prometheus").permitAll()
                        .requestMatchers(HttpMethod.POST,
                                "/api/v1/auth/sms/send",
                                "/api/v1/auth/sms/verify",
                                "/api/v1/auth/signup",
                                "/api/v1/auth/login",
                                "/api/v1/auth/reissue",
                                "/api/v1/auth/logout").permitAll()
                        .requestMatchers(HttpMethod.GET,
                                "/api/v1/auth/availability",
                                "/api/v1/concerts",
                                "/api/v1/concerts/{concertId}",
                                "/api/v1/artists",
                                "/api/v1/artists/{artistId}").permitAll()

                        // Admin endpoints
                        .requestMatchers(HttpMethod.POST, "/api/v1/gates/entries/verify")
                        .hasRole("ADMIN")

                        // Authenticated endpoints
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
