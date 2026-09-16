package com.ssafy.timo.domain.wallet;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.wallet.entity.WalletTransaction;
import com.ssafy.timo.domain.wallet.repository.WalletTransactionRepository;
import com.ssafy.timo.support.IntegrationTest;
import java.math.BigInteger;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.PageRequest;

/** 지갑 거래 내역 저장과 최신순 조회를 실제 MySQL 로 확인한다. */
@IntegrationTest
class WalletTransactionPersistenceTest {

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private WalletTransactionRepository walletTransactionRepository;

    @Test
    @DisplayName("저장된 거래는 최신순으로 조회된다")
    void findAllByMemberId_ordersByCreatedAtDesc() {
        Member member = memberRepository.save(Member.builder()
                .phoneNumber("01011112222").name("정희성").nickname("지갑테스트").build());

        WalletTransaction first = walletTransactionRepository.save(WalletTransaction.builder()
                .member(member).title("머쉬룸 충전").amount(BigInteger.valueOf(1000))
                .balanceAfter(BigInteger.valueOf(1000)).source("PG 모의 결제").build());
        WalletTransaction second = walletTransactionRepository.save(WalletTransaction.builder()
                .member(member).title("콘서트 구매").amount(BigInteger.valueOf(-500))
                .balanceAfter(BigInteger.valueOf(500)).source("예매").build());

        var recent = walletTransactionRepository
                .findAllByMemberIdOrderByCreatedAtDescIdDesc(member.getId(), PageRequest.of(0, 20));

        assertThat(recent).hasSize(2);
        assertThat(recent.get(0).getId()).isEqualTo(second.getId());
        assertThat(recent.get(1).getId()).isEqualTo(first.getId());
        assertThat(recent.get(1).getAmount()).isEqualTo(BigInteger.valueOf(1000));
    }
}
