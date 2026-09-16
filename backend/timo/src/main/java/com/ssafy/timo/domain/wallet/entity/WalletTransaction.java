package com.ssafy.timo.domain.wallet.entity;

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

import java.math.BigInteger;

import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 지갑 잔액이 바뀐 사건 하나(충전·구매·정산·환불 등)의 이력. 온체인 {@code TicketVault.balanceOf}가
 * 유일한 진실이고, 이 행은 "화면에 내역을 보여주기 위한" 오프체인 미러일 뿐이다.
 *
 * <p>{@code amount}는 부호가 있다 - 늘면 양수(충전), 줄면 음수(구매). 종류를 별도 enum으로 두지
 * 않고 부호로만 가른 이유는 프론트가 이미 그렇게(부호만 보고 충전/사용 필터링) 설계돼 있어서다.
 */
@Getter
@Entity
@Table(name = "wallet_transaction")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class WalletTransaction extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "wallet_transaction_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    /** 무엇에 쓰였는지 (예: "머쉬룸 충전", "2026 아이유 콘서트 구매"). */
    @Column(name = "title", nullable = false, length = 200)
    private String title;

    /** 부호 있는 변동액. */
    @Column(name = "amount", nullable = false)
    private BigInteger amount;

    /** 이 거래 직후의 잔액. */
    @Column(name = "balance_after", nullable = false)
    private BigInteger balanceAfter;

    /** 거래가 일어난 곳 (예: "PG 모의 결제", "양도 마켓"). */
    @Column(name = "source", nullable = false, length = 100)
    private String source;

    @Builder
    private WalletTransaction(Member member, String title, BigInteger amount, BigInteger balanceAfter, String source) {
        this.member = member;
        this.title = title;
        this.amount = amount;
        this.balanceAfter = balanceAfter;
        this.source = source;
    }
}
