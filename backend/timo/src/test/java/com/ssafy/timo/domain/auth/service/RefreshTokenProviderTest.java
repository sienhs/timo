package com.ssafy.timo.domain.auth.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.auth.entity.RefreshToken;
import com.ssafy.timo.domain.auth.repository.RefreshTokenRepository;
import com.ssafy.timo.domain.auth.service.RefreshTokenProvider.IssuedRefreshToken;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.global.util.Sha256;
import com.ssafy.timo.support.IntegrationTest;
import java.time.LocalDateTime;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/**
 * refresh 토큰 발급을 실제 MySQL 로 검증한다.
 *
 * <p>메모리가 아니라 테이블에 남는지, 원문이 아니라 해시가 저장되는지, 같은 기기에서 다시 발급할 때
 * 세션이 늘어나지 않고 갈아 끼워지는지를 본다. 마지막 항목이 특히 중요하다. 행이 쌓이면
 * {@code (member_id, device_id)} 유일 제약에 걸려 두 번째 로그인부터 실패한다.
 */
@IntegrationTest
class RefreshTokenProviderTest {

    private static final String DEVICE_A = "11111111-1111-1111-1111-111111111111";
    private static final String DEVICE_B = "22222222-2222-2222-2222-222222222222";

    @Autowired
    private RefreshTokenProvider refreshTokenProvider;

    @Autowired
    private RefreshTokenRepository refreshTokenRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Test
    @DisplayName("발급하면 원문이 아니라 해시가 저장된다")
    void issue_storesHashNotRawValue() {
        Member member = member("01012345678", "티모");

        IssuedRefreshToken issued = refreshTokenProvider.issue(member, DEVICE_A);

        RefreshToken stored = findToken(member, DEVICE_A);
        assertThat(stored.getTokenHash())
                .isNotEqualTo(issued.value())
                .isEqualTo(Sha256.hex(issued.value()));
        assertThat(stored.matches(Sha256.hex(issued.value()))).isTrue();
    }

    @Test
    @DisplayName("발급된 토큰은 매번 다르다")
    void issue_producesDistinctValues() {
        Member member = member("01012345678", "티모");

        String first = refreshTokenProvider.issue(member, DEVICE_A).value();
        String second = refreshTokenProvider.issue(member, DEVICE_A).value();

        assertThat(first).isNotEqualTo(second);
    }

    @Test
    @DisplayName("같은 기기에서 다시 발급하면 세션이 늘지 않고 갈아 끼워진다")
    void issue_replacesSessionOnSameDevice() {
        Member member = member("01012345678", "티모");

        String first = refreshTokenProvider.issue(member, DEVICE_A).value();
        String second = refreshTokenProvider.issue(member, DEVICE_A).value();

        assertThat(refreshTokenRepository.count()).isEqualTo(1);

        RefreshToken stored = findToken(member, DEVICE_A);
        assertThat(stored.matches(Sha256.hex(second))).isTrue();
        // 이전 토큰은 더 이상 통하지 않아야 한다.
        assertThat(stored.matches(Sha256.hex(first))).isFalse();
    }

    @Test
    @DisplayName("기기가 다르면 세션이 따로 생긴다")
    void issue_keepsSessionsPerDevice() {
        Member member = member("01012345678", "티모");

        refreshTokenProvider.issue(member, DEVICE_A);
        refreshTokenProvider.issue(member, DEVICE_B);

        // 폰을 잃어버렸을 때 그 기기만 끊을 수 있어야 한다.
        assertThat(refreshTokenRepository.count()).isEqualTo(2);
        assertThat(findToken(member, DEVICE_A).getTokenHash())
                .isNotEqualTo(findToken(member, DEVICE_B).getTokenHash());
    }

    @Test
    @DisplayName("발급 직후에는 만료되지 않았고 알려준 수명과 만료 시각이 맞는다")
    void issue_setsExpiry() {
        Member member = member("01012345678", "티모");
        LocalDateTime before = LocalDateTime.now();

        IssuedRefreshToken issued = refreshTokenProvider.issue(member, DEVICE_A);

        RefreshToken stored = findToken(member, DEVICE_A);
        assertThat(stored.isExpired(LocalDateTime.now())).isFalse();
        assertThat(stored.getExpiresAt())
                .isAfterOrEqualTo(before.plusSeconds(issued.expiresInSeconds()));
    }

    @Test
    @DisplayName("만료 시각이 지나면 만료로 판정한다")
    void isExpired_afterExpiry() {
        Member member = member("01012345678", "티모");
        refreshTokenProvider.issue(member, DEVICE_A);

        RefreshToken stored = findToken(member, DEVICE_A);

        assertThat(stored.isExpired(stored.getExpiresAt())).isTrue();
        assertThat(stored.isExpired(stored.getExpiresAt().plusDays(1))).isTrue();
        assertThat(stored.isExpired(stored.getExpiresAt().minusSeconds(1))).isFalse();
    }

    private Member member(String phoneNumber, String nickname) {
        return memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber)
                .name("정희성")
                .nickname(nickname)
                .build());
    }

    private RefreshToken findToken(Member member, String deviceId) {
        return refreshTokenRepository.findByMemberIdAndDeviceId(member.getId(), deviceId)
                .orElseThrow(() -> new AssertionError("세션이 저장되지 않았다: deviceId=" + deviceId));
    }
}
