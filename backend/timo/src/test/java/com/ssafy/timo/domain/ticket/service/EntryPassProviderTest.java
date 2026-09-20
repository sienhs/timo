package com.ssafy.timo.domain.ticket.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.ticket.service.EntryPassProvider.EntryPass;
import com.ssafy.timo.domain.ticket.service.EntryPassProvider.EntryPassVerification;
import com.ssafy.timo.domain.ticket.service.EntryPassProvider.EntryPassVerification.Status;
import com.ssafy.timo.global.config.ticket.EntryPassProperties;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 입장 QR 발급·검증을 검증한다.
 *
 * <p>스프링 컨텍스트는 띄우지 않는다. 시계는 {@link Clock#fixed} 로 고정해 만료 전후를 모두 본다.
 */
class EntryPassProviderTest {

    private static final String SECRET = "local-dev-only-entry-pass-secret-0123456789";
    private static final Duration TTL = Duration.ofSeconds(60);
    private static final long TICKET_ID = 324L;
    private static final Instant NOW = Instant.parse("2026-09-17T19:00:00Z");

    private final EntryPassProvider provider = providerAt(NOW);

    @Test
    @DisplayName("발급한 QR 은 다시 검증되고 티켓 번호가 그대로 나온다")
    void issuedPass_isVerifiable() {
        EntryPass pass = provider.issue(TICKET_ID);

        EntryPassVerification verification = provider.verify(pass.value());

        assertThat(verification.isValid()).isTrue();
        assertThat(verification.ticketId()).isEqualTo(TICKET_ID);
        assertThat(pass.expiresInSeconds()).isEqualTo(TTL.toSeconds());
    }

    @Test
    @DisplayName("수명이 지나면 만료로 떨어진다")
    void expiredPass_isRejected() {
        EntryPass pass = provider.issue(TICKET_ID);

        EntryPassVerification verification = providerAt(NOW.plus(TTL).plusSeconds(1)).verify(pass.value());

        assertThat(verification.status()).isEqualTo(Status.EXPIRED);
    }

    @Test
    @DisplayName("만료 시각 정각까지는 아직 유효하다")
    void passAtExactExpiry_isStillValid() {
        EntryPass pass = provider.issue(TICKET_ID);

        EntryPassVerification verification = providerAt(NOW.plus(TTL)).verify(pass.value());

        assertThat(verification.isValid()).isTrue();
    }

    @Test
    @DisplayName("서명을 건드리면 거부된다")
    void tamperedSignature_isRejected() {
        String[] parts = split(provider.issue(TICKET_ID).value());

        String forged = rebuild(parts[0], parts[1], parts[2].substring(1) + "A");

        assertThat(provider.verify(forged).status()).isEqualTo(Status.INVALID);
    }

    @Test
    @DisplayName("만료 시각만 미래로 늘려 잡으면 '만료' 가 아니라 '유효하지 않음' 이다")
    void extendedExpiry_isInvalidNotExpired() {
        String[] parts = split(provider.issue(TICKET_ID).value());
        long stretched = Long.parseLong(parts[1]) + Duration.ofHours(1).toSeconds();

        String forged = rebuild(parts[0], String.valueOf(stretched), parts[2]);

        // 서명을 만료보다 먼저 보기 때문이다. 순서가 반대면 위조가 '시간 지났어요' 로 안내된다.
        assertThat(provider.verify(forged).status()).isEqualTo(Status.INVALID);
    }

    @Test
    @DisplayName("남의 티켓 번호로 바꿔치기하면 거부된다")
    void swappedTicketId_isRejected() {
        String[] parts = split(provider.issue(TICKET_ID).value());

        String forged = rebuild("999", parts[1], parts[2]);

        assertThat(provider.verify(forged).status()).isEqualTo(Status.INVALID);
    }

    @Test
    @DisplayName("다른 비밀키로 만든 QR 은 거부된다")
    void passSignedWithAnotherSecret_isRejected() {
        EntryPassProvider attacker = new EntryPassProvider(
                new EntryPassProperties("a-completely-different-secret-0123456789", TTL),
                Clock.fixed(NOW, ZoneId.of("Asia/Seoul")));

        EntryPass forged = attacker.issue(TICKET_ID);

        assertThat(provider.verify(forged.value()).status()).isEqualTo(Status.INVALID);
    }

    @Test
    @DisplayName("우리 형식이 아닌 문자열은 전부 거부된다")
    void foreignStrings_areRejected() {
        String valid = provider.issue(TICKET_ID).value();

        assertThat(provider.verify(null).status()).isEqualTo(Status.INVALID);
        assertThat(provider.verify("").status()).isEqualTo(Status.INVALID);
        assertThat(provider.verify("https://example.com").status()).isEqualTo(Status.INVALID);
        // 구버전 앱이 만든 QR. 접두사는 비슷해도 서명이 없다.
        assertThat(provider.verify("timo:entry:324:1789012345:abc").status()).isEqualTo(Status.INVALID);
        // 버전만 v2 로 바꿔 끼운 것. 서명 대상에 버전이 들어 있어 여기서 걸린다.
        assertThat(provider.verify(valid.replaceFirst("timo:entry:1:", "timo:entry:2:")).status())
                .isEqualTo(Status.INVALID);
    }

    @Test
    @DisplayName("QR 문자열은 짧게 유지된다")
    void passStaysShort() {
        // 길이가 늘면 QR 버전이 올라가 칸이 촘촘해지고, 어두운 입장 줄에서 인식률이 떨어진다.
        // 페이로드에 필드를 더 싣고 싶어지면 여기서 한 번 걸린다.
        assertThat(provider.issue(TICKET_ID).value()).hasSizeLessThan(60);
    }

    private static EntryPassProvider providerAt(Instant instant) {
        return new EntryPassProvider(
                new EntryPassProperties(SECRET, TTL),
                Clock.fixed(instant, ZoneId.of("Asia/Seoul")));
    }

    /** {@code timo:entry:1:<ticketId>.<exp>.<sig>} 를 세 조각으로 가른다. */
    private static String[] split(String qr) {
        return qr.substring("timo:entry:1:".length()).split("[.]");
    }

    private static String rebuild(String ticketId, String expiresAt, String signature) {
        return "timo:entry:1:%s.%s.%s".formatted(ticketId, expiresAt, signature);
    }
}
