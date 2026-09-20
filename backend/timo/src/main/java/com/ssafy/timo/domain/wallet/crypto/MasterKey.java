package com.ssafy.timo.domain.wallet.crypto;

import com.ssafy.timo.global.config.wallet.WalletProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.regex.Pattern;

/**
 * 커스터디얼 지갑 마스터키를 감싸는 값 타입.
 *
 * <p>원문은 {@link #expose()}로만 제공하며, {@link #toString()}은
 * 키 비교용 지문만 반환해 로그에 원문이 노출되는 것을 방지한다.
 * 메모리 내 평문 키 보호는 이 타입의 범위에 포함하지 않는다.
 *
 * <p>{@link #of(String)}은 설정값 바인딩에 사용하는 정적 팩토리 메서드다.
 */
public final class MasterKey {

    private static final Pattern FORMAT = Pattern.compile("^[0-9a-fA-F]{64}$");
    private static final String GENERATION_HINT =
            "생성 예시: node -e \"console.log(require('crypto').randomBytes(32).toString('hex'))\"";
    private static final int FINGERPRINT_HEX_LENGTH = 8;

    private final String value;

    private MasterKey(String value) {
        this.value = value;
    }

    /**
     * 64자 16진수 문자열(32바이트)인지 검증한 뒤 감싼다. 형식이 틀리면 기동 시점에 바로 예외를 던진다.
     */
    public static MasterKey of(String rawValue) {
        if (rawValue == null || rawValue.isBlank()) {
            throw new IllegalStateException("wallet.master-key 가 설정되지 않았습니다. " + GENERATION_HINT);
        }
        if (!FORMAT.matcher(rawValue).matches()) {
            throw new IllegalStateException(
                    "wallet.master-key 는 64자 16진수 문자열(32바이트)이어야 합니다. " + GENERATION_HINT);
        }
        return new MasterKey(rawValue);
    }

    /**
     * 원문을 그대로 돌려준다. 실제로 암복호화에 쓰는 곳에서만 호출하고, 그 반환값을 로그·예외 메시지·응답 본문 어디에도 다시 담지 않는다.
     */
    public String expose() {
        return value;
    }

    @Override
    public boolean equals(Object other) {
        return other instanceof MasterKey masterKey && value.equals(masterKey.value);
    }

    @Override
    public int hashCode() {
        return value.hashCode();
    }

    @Override
    public String toString() {
        return "MasterKey[fp:%s]".formatted(fingerprint(value));
    }

    /**
     * 원문을 복원할 수 없는 짧은 식별자. 값 자체가 아니라 '이 값과 저 값이 같은가?' 만 답하기 위한 용도.
     */
    private static String fingerprint(String rawValue) {
        try {
            byte[] hash = MessageDigest.getInstance("SHA-256").digest(rawValue.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(hash, 0, FINGERPRINT_HEX_LENGTH / 2);
        } catch (NoSuchAlgorithmException e) {
            throw new AssertionError("SHA-256 알고리즘을 찾을 수 없습니다", e);
        }
    }
}
