package com.ssafy.timo.domain.wallet.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.wallet.crypto.CustodialWalletCrypto;
import com.ssafy.timo.domain.wallet.crypto.CustodialWalletMaterial;
import com.ssafy.timo.domain.wallet.entity.Wallet;
import com.ssafy.timo.domain.wallet.repository.WalletRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class WalletServiceTest {

    private static final String ADDRESS = "0xF90259A926dE751ed07d2e8908868A3d2D2C4a7A";
    private static final String KEYSTORE_JSON = "{\"version\":3}";
    private static final String WRAPPED_DEK = "wrapped-dek-dummy-value";

    @Mock
    private CustodialWalletCrypto custodialWalletCrypto;

    @Mock
    private WalletRepository walletRepository;

    @InjectMocks
    private WalletService walletService;

    @Captor
    private ArgumentCaptor<Wallet> walletCaptor;

    @Test
    @DisplayName("크립토 유틸이 만든 산출물을 회원과 묶어 저장한다")
    void createWallet_savesWalletBuiltFromCryptoMaterialAndMember() {
        Member member = Member.builder().phoneNumber("01012345678").name("정희성").nickname("티모").build();
        CustodialWalletMaterial material = new CustodialWalletMaterial(ADDRESS, KEYSTORE_JSON, WRAPPED_DEK);
        given(custodialWalletCrypto.create()).willReturn(material);
        given(walletRepository.save(any(Wallet.class))).willAnswer(invocation -> invocation.getArgument(0));

        walletService.createWallet(member);

        then(walletRepository).should().save(walletCaptor.capture());
        Wallet saved = walletCaptor.getValue();
        assertThat(saved.getMember()).isEqualTo(member);
        assertThat(saved.getAddress()).isEqualTo(ADDRESS);
        assertThat(saved.getEncryptedKeystoreJson()).isEqualTo(KEYSTORE_JSON);
        assertThat(saved.getWrappedDek()).isEqualTo(WRAPPED_DEK);
    }

    @Test
    @DisplayName("저장된 지갑을 그대로 반환한다")
    void createWallet_returnsTheSavedWallet() {
        Member member = Member.builder().phoneNumber("01012345678").name("정희성").nickname("티모").build();
        given(custodialWalletCrypto.create())
                .willReturn(new CustodialWalletMaterial(ADDRESS, KEYSTORE_JSON, WRAPPED_DEK));
        Wallet saved = Wallet.builder()
                .member(member).address(ADDRESS).encryptedKeystoreJson(KEYSTORE_JSON).wrappedDek(WRAPPED_DEK).build();
        given(walletRepository.save(any(Wallet.class))).willReturn(saved);

        Wallet result = walletService.createWallet(member);

        assertThat(result).isSameAs(saved);
    }
}
