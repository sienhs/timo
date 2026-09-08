package com.ssafy.timo.global.util;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * 고엔트로피 비밀값을 저장 전에 한 번 접어 두는 용도.
 *
 * <p>인증 코드·검증 티켓·refresh 토큰처럼 <b>우리가 만든 랜덤값</b>에만 쓴다. Redis 덤프가 새어 나가도
 * 저장된 값을 그대로 제출할 수 없게 하는 게 목적이다.
 *
 * <p>비밀번호에는 쓰면 안 된다. 사람이 고른 비밀번호는 엔트로피가 낮아 사전 대입이 통하므로
 * 느리게 설계된 BCrypt 가 필요하다. 반대로 여기 오는 값들은 32바이트 랜덤이라 대입이 불가능하고,
 * 재발급마다 수백 밀리초를 쓸 이유가 없다. 그래서 둘을 일부러 갈라 둔다.
 */
public final class Sha256 {

    private static final String ALGORITHM = "SHA-256";

    private Sha256() {
    }

    public static String hex(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance(ALGORITHM);
            return HexFormat.of().formatHex(digest.digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException e) {
            // 표준 JDK 라면 도달할 수 없다.
            throw new IllegalStateException(ALGORITHM + " is not available", e);
        }
    }
}
