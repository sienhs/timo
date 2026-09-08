package com.ssafy.timo.global.config;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import com.ssafy.timo.global.security.ExpiryAwareJwtValidator;
import java.nio.charset.StandardCharsets;
import javax.crypto.SecretKey;
import javax.crypto.spec.SecretKeySpec;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtGrantedAuthoritiesConverter;

/**
 * JWT 발급·검증 부품.
 *
 * <p>대칭키(HS256)를 쓰므로 발급과 검증이 같은 키를 공유한다. 공개키 방식이 아니라
 * {@code issuer-uri} 로 키를 받아 올 곳이 없어, 디코더도 인코더도 여기서 직접 만든다.
 */
@Configuration
@EnableConfigurationProperties(JwtProperties.class)
@RequiredArgsConstructor
public class JwtConfig {

    private static final String HMAC_ALGORITHM = "HmacSHA256";

    private final JwtProperties jwtProperties;

    /**
     * 토큰 검증기.
     *
     * <p>Resource Server 가 이 빈으로 들어온 토큰을 푼다. {@code oauth2ResourceServer(jwt)} 를
     * 켠 채 이 빈이 없으면 기동이 실패하므로 둘은 항상 같이 있어야 한다.
     *
     * <p>검증기를 {@link ExpiryAwareJwtValidator} 로 바꿔 끼운다. 기본 검증은 그대로 위임하고
     * 만료일 때만 식별 가능한 표시를 남기는데, 이게 없으면 만료와 그 밖의 검증 실패를 구분할 수 없어
     * 앱이 재발급 루프에 빠질 수 있다. 자세한 이유는 그 클래스 주석 참고.
     */
    @Bean
    public JwtDecoder jwtDecoder() {
        NimbusJwtDecoder jwtDecoder = NimbusJwtDecoder.withSecretKey(secretKey())
                .macAlgorithm(MacAlgorithm.HS256)
                .build();
        jwtDecoder.setJwtValidator(new ExpiryAwareJwtValidator());

        return jwtDecoder;
    }

    /** 토큰 발급기. Resource Server 는 검증만 하므로 발급 쪽은 우리가 붙여야 한다. */
    @Bean
    public JwtEncoder jwtEncoder() {
        return new NimbusJwtEncoder(new ImmutableSecret<>(secretKey()));
    }

    /**
     * 권한 변환기.
     *
     * <p>기본 변환기는 {@code scope}/{@code scp} 클레임을 읽어 {@code SCOPE_} 접두사를 붙인다.
     * 우리는 {@code roles} 클레임에 역할을 담고 {@code hasRole()} 로 검사하므로 둘 다 갈아 끼운다.
     */
    @Bean
    public JwtAuthenticationConverter jwtAuthenticationConverter() {
        JwtGrantedAuthoritiesConverter authoritiesConverter = new JwtGrantedAuthoritiesConverter();
        authoritiesConverter.setAuthoritiesClaimName("roles");
        authoritiesConverter.setAuthorityPrefix("ROLE_");

        JwtAuthenticationConverter converter = new JwtAuthenticationConverter();
        converter.setJwtGrantedAuthoritiesConverter(authoritiesConverter);
        return converter;
    }

    private SecretKey secretKey() {
        return new SecretKeySpec(
                jwtProperties.secret().getBytes(StandardCharsets.UTF_8), HMAC_ALGORITHM);
    }
}
