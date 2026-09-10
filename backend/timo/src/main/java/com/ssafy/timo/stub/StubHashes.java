package com.ssafy.timo.stub;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;

/**
 * 온체인 식별자 모양({@code 0x} + 64 hex)의 값을 만든다. 주문 id·거래 id·충전 ref·트랜잭션 해시에 쓴다.
 *
 * <p>설계 초안 5절의 규칙 {@code keccak256("order:" + id)} 을 흉내 낸다. Keccak 은 JDK 에 없어 SHA-256 으로
 * 대신하지만 길이와 모양은 같다. 화면은 값의 내용이 아니라 모양만 본다. 같은 seed 면 같은 값이 나와
 * 재시도에도 멱등키가 흔들리지 않는다.
 */
public final class StubHashes {

    public static String of(String seed) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(seed.getBytes(StandardCharsets.UTF_8));
            return "0x" + HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 을 지원하지 않는 JVM", e);
        }
    }

    private StubHashes() {
    }
}
