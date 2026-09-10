package com.ssafy.timo.domain.auth.service;

import com.ssafy.timo.domain.auth.entity.RefreshToken;
import com.ssafy.timo.domain.auth.repository.RefreshTokenRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.global.util.Masked;
import com.ssafy.timo.global.util.Sha256;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Base64;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * refresh 토큰 발급기.
 *
 * <p><b>JWT 가 아니다.</b> 32바이트 난수다. refresh 는 서버가 확실히 무효화할 수 있어야 하는데
 * JWT 는 발급하고 나면 서명만으로 검증되어 되돌릴 수단이 없다. 어차피 매 재발급마다 저장소를
 * 들여다봐야 하므로 자체 검증이 되는 형식일 이유도 없다.
 *
 * <p>수명은 {@link AccessTokenProvider} 와 정반대로 길게 잡는다. access 는 무효화가 불가능해
 * 짧은 수명이 유일한 방어선이지만, refresh 는 언제든 지울 수 있어 길어도 통제된다.
 * 이 둘이 세트로 움직여야 "자주 로그아웃되지 않으면서도 탈취 시 끊을 수 있는" 상태가 된다.
 */
@Service
@RequiredArgsConstructor
public class RefreshTokenProvider {

    /**
     * 이 기간 동안 앱을 한 번도 안 열면 다시 로그인해야 한다.
     * 재발급이 일어나면 그 시점부터 다시 센다({@link #renew}).
     *
     * <p>짧게 잡으면 안 된다. 예매 앱은 공연이 있을 때만 열리는 앱이라 2주 미사용이 흔하고,
     * 하필 티켓팅 순간에 로그인 화면을 보게 되면 좌석을 놓친다. 유출 대비는 수명이 아니라
     * 세션 폐기(로그아웃·비밀번호 변경)와 지갑 서명 step-up 으로 잡는다.
     */
    private static final Duration TTL = Duration.ofDays(30);

    /** 128비트면 충분하지만 저장 비용이 없으므로 넉넉히 잡는다. */
    private static final int TOKEN_BYTES = 32;

    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final RefreshTokenRepository refreshTokenRepository;

    /**
     * 새 refresh 토큰을 만들어 저장하고 원문을 돌려준다.
     *
     * <p>원문은 여기서 딱 한 번 나가고 서버 어디에도 남지 않는다. 저장되는 건 해시뿐이라
     * 분실하면 재발급 외에 방법이 없고, 그게 의도다.
     *
     * <p>같은 기기에 이미 세션이 있으면 행을 갈아 끼운다. 지우고 새로 넣으면 JPA 가 INSERT 를
     * 먼저 내보낼 수 있어 {@code (member_id, device_id)} 유일 제약과 부딪힌다.
     */
    @Transactional
    public IssuedRefreshToken issue(Member member, String deviceId) {
        String value = generate();
        String tokenHash = Sha256.hex(value);
        LocalDateTime expiresAt = LocalDateTime.now().plus(TTL);

        refreshTokenRepository.findByMemberIdAndDeviceId(member.getId(), deviceId)
                .ifPresentOrElse(
                        existing -> existing.rotate(tokenHash, expiresAt),
                        () -> refreshTokenRepository.save(RefreshToken.builder()
                                .member(member)
                                .deviceId(deviceId)
                                .tokenHash(tokenHash)
                                .expiresAt(expiresAt)
                                .build()));

        return new IssuedRefreshToken(value, TTL.toSeconds());
    }

    /**
     * 살아 있는 세션의 만료를 지금부터 다시 센다.
     *
     * <p>수명을 여기 한 곳에만 두려고 메서드로 뺐다. 재발급 쪽에서 {@code TTL} 을 다시 계산하면
     * 발급과 갱신의 기준이 갈라져 "로그인은 30일인데 재발급은 14일" 같은 상태가 조용히 생긴다.
     */
    @Transactional
    public void renew(RefreshToken session) {
        session.extend(LocalDateTime.now().plus(TTL));
    }

    private String generate() {
        byte[] bytes = new byte[TOKEN_BYTES];
        SECURE_RANDOM.nextBytes(bytes);

        // URL 안전 문자만 쓴다. 헤더·쿼리·JSON 어디에 실려도 이스케이프가 필요 없다.
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    /**
     * 발급된 refresh 토큰.
     *
     * @param value            토큰 원문. 이 순간 이후로는 서버에서 다시 꺼낼 수 없다
     * @param expiresInSeconds 남은 수명(초)
     */
    public record IssuedRefreshToken(String value, long expiresInSeconds) {

        @Override
        public String toString() {
            return "IssuedRefreshToken[value=%s, expiresInSeconds=%d]".formatted(Masked.of(value), expiresInSeconds);
        }
    }
}
