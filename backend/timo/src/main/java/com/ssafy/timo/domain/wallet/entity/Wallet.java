package com.ssafy.timo.domain.wallet.entity;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.MapsId;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 회원의 커스터디얼 지갑.
 *
 * <p>{@link Member} 와 1:1 이고 회원 식별자를 PK 로 공유한다.
 *
 * <p>여기 담긴 {@code encryptedKeystoreJson}·{@code wrappedDek}는 이미 두 겹으로 암호화된 산출물이다.
 * <p>실제 암복호화는 {@link com.ssafy.timo.domain.wallet.crypto.CustodialWalletCrypto} 가 맡고,
 * 이 엔티티는 그 결과를 회원과 묶어 저장하는 역할만 한다.
 */
@Getter
@Entity
@Table(name = "wallet",
        uniqueConstraints = @UniqueConstraint(name = "uk_wallet_address", columnNames = "address"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Wallet extends BaseEntity {

    /** PK 이자 FK. 값은 {@link MapsId} 가 {@link #member} 에서 가져와 채운다. */
    @Id
    @Column(name = "member_id")
    private Long memberId;

    @MapsId
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    private Member member;

    /** 이더리움 주소 (소문자 고정, {@code 0x} 접두 40자 = 총 42자). */
    @Column(nullable = false, length = 42)
    private String address;

    @Column(name = "encrypted_keystore_json", nullable = false, columnDefinition = "TEXT")
    private String encryptedKeystoreJson;

    @Column(name = "wrapped_dek", nullable = false, length = 255)
    private String wrappedDek;

    @Builder
    private Wallet(Member member, String address, String encryptedKeystoreJson, String wrappedDek) {
        this.member = member;
        this.address = address;
        this.encryptedKeystoreJson = encryptedKeystoreJson;
        this.wrappedDek = wrappedDek;
    }
}
