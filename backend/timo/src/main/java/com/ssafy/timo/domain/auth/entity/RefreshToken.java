package com.ssafy.timo.domain.auth.entity;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 기기 하나의 로그인 세션.
 *
 * <p>메모리가 아니라 테이블에 둔다. SMS 인증 코드는 수명이 3분이라 재시작 때 날아가도
 * "다시 받으세요" 로 끝나지만, 이 값의 수명은 몇 주다. 메모리에 두면 <b>배포할 때마다
 * 로그인한 사용자 전원이 로그아웃</b>되고, 인스턴스가 둘 이상이면 세션이 한쪽에만 있어
 * 재발급이 무작위로 실패한다.
 *
 * <p>토큰 원문이 아니라 SHA-256 해시를 저장한다. DB 덤프가 새어 나가도 그 값을 그대로
 * 제출할 수 없게 하려는 것이다. 대조는 {@link #matches(String)} 로만 한다.
 *
 * <p>{@code (member_id, device_id)} 가 유일하다. 기기당 세션이 하나여야 폰을 잃어버렸을 때
 * 그 기기만 끊을 수 있다. 회원 단위로 잡으면 태블릿까지 같이 로그아웃된다.
 *
 * <p><b>TODO</b>: 만료된 행은 지워지지 않고 쌓인다. 재발급 흐름을 붙일 때
 * {@code expiresAt} 이 지난 행을 주기적으로 정리하는 작업을 함께 만든다.
 */
@Getter
@Entity
@Table(name = "refresh_token",
        uniqueConstraints = {
                @UniqueConstraint(
                        name = "uk_refresh_token_member_device",
                        columnNames = {"member_id", "device_id"}),
                // 재발급은 토큰 해시만 들고 들어온다. 인덱스가 없으면 세션이 늘어날수록
                // 매 재발급이 풀스캔이 된다. 유일하기도 해야 조회 결과가 하나로 확정된다.
                @UniqueConstraint(
                        name = "uk_refresh_token_hash",
                        columnNames = "token_hash")})
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class RefreshToken extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "refresh_token_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    /** 클라이언트가 만들어 기기에 보관하는 UUID. */
    @Column(name = "device_id", nullable = false, length = 64)
    private String deviceId;

    /** SHA-256 16진 표기라 길이가 64로 고정이다. */
    @Column(name = "token_hash", nullable = false, length = 64)
    private String tokenHash;

    @Column(name = "expires_at", nullable = false)
    private LocalDateTime expiresAt;

    @Builder
    private RefreshToken(Member member, String deviceId, String tokenHash, LocalDateTime expiresAt) {
        this.member = member;
        this.deviceId = deviceId;
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
    }

    /**
     * 같은 기기에 새 토큰을 발급하며 기존 것을 무효로 만든다.
     *
     * <p>행을 지우고 새로 넣는 대신 갈아 끼운다. 그래야 {@code (member_id, device_id)} 유일 제약과
     * 부딪히지 않고, {@code updated_at} 이 마지막 재발급 시각으로 남는다.
     */
    public void rotate(String tokenHash, LocalDateTime expiresAt) {
        this.tokenHash = tokenHash;
        this.expiresAt = expiresAt;
    }

    /**
     * 만료 시각을 다시 민다.
     *
     * <p>access 만 재발급하는 구조라 이게 없으면 <b>앱을 매일 쓰는 사용자도 최초 로그인
     * 이후 수명이 다하면 그냥 튕긴다.</b> 재발급 때마다 밀어 줘야 활성 사용자는 안 풀리고
     * 방치된 세션만 만료된다. 기기를 잃어버렸을 때 언젠가는 끊기게 하려면 무한이면 안 된다.
     */
    public void extend(LocalDateTime expiresAt) {
        this.expiresAt = expiresAt;
    }

    public boolean isExpired(LocalDateTime now) {
        return !now.isBefore(expiresAt);
    }

    /**
     * 제출된 토큰의 해시가 저장된 것과 같은지 본다.
     *
     * <p>일반 문자열 비교 대신 {@link MessageDigest#isEqual} 을 쓴다. 앞에서부터 다른 지점에
     * 도달하면 즉시 끝나는 비교는 응답 시간 차이로 해시를 한 글자씩 알아낼 여지를 준다.
     */
    public boolean matches(String tokenHash) {
        return MessageDigest.isEqual(
                this.tokenHash.getBytes(StandardCharsets.UTF_8),
                tokenHash.getBytes(StandardCharsets.UTF_8));
    }
}
