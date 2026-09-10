package com.ssafy.timo.domain.wallet.service;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.wallet.crypto.CustodialWalletCrypto;
import com.ssafy.timo.domain.wallet.crypto.CustodialWalletMaterial;
import com.ssafy.timo.domain.wallet.entity.Wallet;
import com.ssafy.timo.domain.wallet.repository.WalletRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원의 커스터디얼 지갑 생성.
 *
 * <p>암복호화는 {@link CustodialWalletCrypto} 가 맡고, 이 서비스는 그 산출물을 회원과 묶어 {@link WalletRepository} 에 저장하는 역할만 한다.
 * <p>{@code @Transactional} 을 붙였지만, 실제로는 회원가입 흐름({@code SignupService.signUp()})의 트랜잭션에 합류하는 경우가 대부분이다.
 */
@Service
@RequiredArgsConstructor
public class WalletService {

    private final CustodialWalletCrypto custodialWalletCrypto;
    private final WalletRepository walletRepository;

    @Transactional
    public Wallet createWallet(Member member) {
        CustodialWalletMaterial material = custodialWalletCrypto.create();

        return walletRepository.save(Wallet.builder()
                .member(member)
                .address(material.address())
                .encryptedKeystoreJson(material.encryptedKeystoreJson())
                .wrappedDek(material.wrappedDek())
                .build());
    }
}
