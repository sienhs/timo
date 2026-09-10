package com.ssafy.timo.domain.auth.service;

import com.ssafy.timo.domain.member.entity.Role;
import com.ssafy.timo.global.config.JwtProperties;
import com.ssafy.timo.global.util.Masked;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

/**
 * access token 발급기.
 *
 * <p>담기는 것은 <b>식별자와 권한뿐</b>이다. 전화번호·이름·닉네임은 넣지 않는다.
 * JWT 는 서명이지 암호화가 아니라 누구나 본문을 읽을 수 있고, 앱·프록시·로그를 거치는 동안
 * 그대로 노출된다. 회원 정보가 필요하면 {@code sub} 로 다시 조회한다.
 *
 * <p>발급한 뒤에는 무효화할 방법이 없다. 그래서 수명이 유일한 방어선이고
 * ({@link JwtProperties#accessTokenTtl()}, 기본 30분), 세션을 실제로 끊는 일은
 * refresh 토큰 쪽에서 한다.
 *
 * <p>{@code jti} 를 넣어 두는 이유는 지금 쓰기 위해서가 아니라 나중을 위해서다. 탈취가 의심될 때
 * "이 토큰 하나"를 지목해 감사 로그에서 추적하거나 차단 목록에 올리려면 토큰마다 다른 식별자가 있어야 하는데,
 * 발급을 시작한 뒤에 넣으면 그 이전에 나간 토큰들은 영영 지목할 수 없다.
 */
@Service
@RequiredArgsConstructor
public class AccessTokenProvider {

    private static final String ROLES_CLAIM = "roles";

    private final JwtEncoder jwtEncoder;
    private final JwtProperties jwtProperties;

    public AccessToken issue(Long memberId, Role role) {
        Instant issuedAt = Instant.now();
        Instant expiresAt = issuedAt.plus(jwtProperties.accessTokenTtl());

        JwtClaimsSet claims = JwtClaimsSet.builder()
                .subject(String.valueOf(memberId))
                .claim(ROLES_CLAIM, List.of(role.name()))
                .issuedAt(issuedAt)
                .expiresAt(expiresAt)
                .id(UUID.randomUUID().toString())
                .build();

        String value = jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();

        return new AccessToken(value, jwtProperties.accessTokenTtl().toSeconds());
    }

    /**
     * 발급된 access token.
     *
     * @param value            토큰 문자열
     * @param expiresInSeconds 남은 수명(초). 앱이 만료 직전에 미리 재발급할 수 있도록 함께 내려준다
     */
    public record AccessToken(String value, long expiresInSeconds) {

        @Override
        public String toString() {
            return "AccessToken[value=%s, expiresInSeconds=%d]".formatted(Masked.of(value), expiresInSeconds);
        }
    }
}
