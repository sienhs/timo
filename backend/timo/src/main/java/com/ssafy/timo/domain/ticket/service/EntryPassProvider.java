package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.global.config.ticket.EntryPassProperties;
import com.ssafy.timo.global.util.Masked;
import java.nio.charset.StandardCharsets;
import java.security.InvalidKeyException;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.Instant;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Service;

/**
 * 입장 QR 한 장을 만들고(발급) 다시 푸는(검증) 코덱.
 *
 * <p>QR 문자열은 <b>서버만</b> 만들 수 있어야 한다. 앱이 규칙대로 조립하는 방식이면 규칙을 아는
 * 누구나 남의 티켓 QR 을 찍어낼 수 있다. 그래서 서버가 HMAC 으로 서명하고, 팬 앱도 게이트 앱도
 * 이 문자열을 해석하지 않고 그대로 나르기만 한다.
 *
 * <p>지갑 서명을 쓰지 않는 이유. 지갑이 커스터디얼({@code CustodialWalletCrypto})이라 개인키를
 * 서버가 들고 있다. 유저 기기엔 서명할 키가 없고 서버가 대신 서명하면 "서버가 서버에게" 증명하는
 * 꼴이라 아무것도 보장하지 못한다. 온체인 소유권은 서명이 아니라 검증 시점에
 * {@code ownerOf(tokenId)} 로 직접 확인한다.
 *
 * <h2>형식</h2>
 * <pre>
 * timo:entry:1:&lt;ticketId&gt;.&lt;exp&gt;.&lt;sig&gt;
 * </pre>
 *
 * <p>JSON 을 base64 로 싣지 않고 점으로 이어 붙인 숫자만 쓴다. QR 은 담는 글자가 늘수록 칸이
 * 촘촘해져 인식률이 떨어지는데, 입장 줄은 어둡고 화면은 흔들리고 지문도 묻어 있다. 이 형식이면
 * 50자 안쪽이라 낮은 버전 QR 로 찍혀 그런 조건에서도 한 번에 읽힌다.
 *
 * <p>페이로드에 티켓 번호와 만료뿐인 것도 같은 이유다. 공연·회원·좌석은 전부 티켓에서 다시
 * 조회할 수 있고, 조회한 값이 어차피 판정 기준이다. QR 에 실어 봐야 길이만 늘고 대조할 일도 없다.
 *
 * <p>서명 대상에 {@code timo:entry:1:} 접두사까지 포함한다. 버전을 서명 밖에 두면 나중에 v2 가
 * 생겼을 때 v2 토큰의 버전만 1 로 바꿔치기해 v1 검증기에 먹이는 길이 열린다.
 */
@Service
public class EntryPassProvider {

    private static final String PREFIX = "timo:entry:";
    private static final int VERSION = 1;
    private static final String VERSIONED_PREFIX = PREFIX + VERSION + ":";

    private static final String HMAC_ALGORITHM = "HmacSHA256";

    /**
     * 서명을 32바이트 전부가 아니라 앞 16바이트(128비트)만 싣는다. QR 길이를 22자 아끼면서도
     * 위조에 필요한 시도 횟수는 2^128 로 남는다 - 60초짜리 토큰에 그 이상은 의미가 없다.
     */
    private static final int SIGNATURE_BYTES = 16;

    private static final Base64.Encoder BASE64 = Base64.getUrlEncoder().withoutPadding();

    private final SecretKeySpec secretKey;
    private final EntryPassProperties properties;
    private final Clock clock;

    public EntryPassProvider(EntryPassProperties properties, Clock clock) {
        this.properties = properties;
        this.clock = clock;
        this.secretKey = new SecretKeySpec(
                properties.secret().getBytes(StandardCharsets.UTF_8), HMAC_ALGORITHM);
    }

    /**
     * 티켓 하나의 입장 QR 을 발급한다.
     *
     * <p>이 티켓을 요청한 사람이 정말 가져도 되는지는 여기서 보지 않는다. 소유자·상태·공연
     * 시간대 확인은 호출하는 서비스의 몫이고, 여기는 확인이 끝났다는 전제로 서명만 한다.
     */
    public EntryPass issue(Long ticketId) {
        Instant expiresAt = Instant.now(clock).plus(properties.ttl());
        String payload = "%d.%d".formatted(ticketId, expiresAt.getEpochSecond());

        return new EntryPass(
                VERSIONED_PREFIX + payload + "." + sign(VERSIONED_PREFIX + payload),
                properties.ttl().toSeconds());
    }

    /**
     * 게이트가 읽어 온 문자열을 검증한다.
     *
     * <p>만료보다 서명을 <b>먼저</b> 본다. 순서가 반대면 만료 시각만 미래로 고쳐 쓴 위조 QR 이
     * "유효 시간이 지났어요" 로 안내되어, 운영자는 다시 찍어 보라고만 하고 위조 시도는 그냥
     * 묻힌다. 서명이 깨졌으면 그 안의 값은 하나도 믿을 게 없으니 읽지도 않는다.
     *
     * <p>형식 오류와 서명 불일치를 {@link Status#INVALID} 하나로 합친 것은 의도한 것이다.
     * 둘을 나눠 알려주면 위조를 시도하는 쪽에 "형식은 맞았다" 는 힌트를 주게 된다.
     */
    public EntryPassVerification verify(String qr) {
        if (qr == null || !qr.startsWith(VERSIONED_PREFIX)) {
            return EntryPassVerification.invalid();
        }

        String[] parts = qr.substring(VERSIONED_PREFIX.length()).split("[.]");
        if (parts.length != 3) {
            return EntryPassVerification.invalid();
        }

        String signed = qr.substring(0, qr.lastIndexOf('.'));
        if (!MessageDigest.isEqual(
                sign(signed).getBytes(StandardCharsets.UTF_8),
                parts[2].getBytes(StandardCharsets.UTF_8))) {
            return EntryPassVerification.invalid();
        }

        long ticketId;
        long expiresAtEpochSecond;
        try {
            ticketId = Long.parseLong(parts[0]);
            expiresAtEpochSecond = Long.parseLong(parts[1]);
        } catch (NumberFormatException e) {
            // 서명까지 통과했는데 숫자가 아니면 우리가 발급한 적 없는 조합이다.
            return EntryPassVerification.invalid();
        }

        // 게이트 단말의 시계는 보지 않는다. 기기 시각이 몇 분 밀려 있으면 멀쩡한 QR 이
        // 전부 만료로 떨어지거나, 반대로 만료된 QR 이 통과한다.
        if (Instant.now(clock).getEpochSecond() > expiresAtEpochSecond) {
            return EntryPassVerification.expired();
        }

        return EntryPassVerification.valid(ticketId);
    }

    private String sign(String message) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(secretKey);
            byte[] digest = mac.doFinal(message.getBytes(StandardCharsets.UTF_8));
            return BASE64.encodeToString(Arrays.copyOf(digest, SIGNATURE_BYTES));
        } catch (NoSuchAlgorithmException | InvalidKeyException e) {
            // 알고리즘 이름은 상수고 키는 기동 시점에 검증했다. 여기 오면 설정이 아니라 런타임 문제다.
            throw new IllegalStateException("입장 QR 서명에 실패했습니다.", e);
        }
    }

    /**
     * 발급된 입장 QR.
     *
     * @param value            QR 에 그대로 실리는 문자열
     * @param expiresInSeconds 남은 수명(초). 앱이 만료 직전에 미리 재발급할 수 있도록 함께 내려준다
     */
    public record EntryPass(String value, long expiresInSeconds) {

        /** 60초짜리라도 이 문자열 하나로 입장이 되므로, 로그에 원문이 남지 않게 가린다. */
        @Override
        public String toString() {
            return "EntryPass[value=%s, expiresInSeconds=%d]".formatted(Masked.of(value), expiresInSeconds);
        }
    }

    /**
     * 검증 결과.
     *
     * <p>여기서 가리는 것은 <b>문자열 자체가 우리 것이고 아직 살아 있는가</b> 뿐이다. 이미 입장한
     * 티켓인지, 회수된 티켓인지, 이 게이트가 맡은 공연이 맞는지는 티켓을 조회해야 알 수 있어
     * 호출하는 서비스가 이어서 판단한다.
     *
     * @param status   판정
     * @param ticketId {@link Status#VALID} 일 때만 값이 있다
     */
    public record EntryPassVerification(Status status, Long ticketId) {

        public enum Status {
            VALID,
            /** 수명이 지났다. 게이트 {@code reasonCode} 로는 {@code EXPIRED}. */
            EXPIRED,
            /** 형식이 다르거나 서명이 맞지 않는다. 게이트 {@code reasonCode} 로는 {@code INVALID}. */
            INVALID
        }

        static EntryPassVerification valid(long ticketId) {
            return new EntryPassVerification(Status.VALID, ticketId);
        }

        static EntryPassVerification expired() {
            return new EntryPassVerification(Status.EXPIRED, null);
        }

        static EntryPassVerification invalid() {
            return new EntryPassVerification(Status.INVALID, null);
        }

        public boolean isValid() {
            return status == Status.VALID;
        }
    }
}
