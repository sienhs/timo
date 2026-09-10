package com.ssafy.timo.domain.auth.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;

import com.ssafy.timo.domain.auth.dto.SignupRequestDto;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.auth.repository.SmsVerificationStore;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.wallet.crypto.WalletCryptoException;
import com.ssafy.timo.domain.wallet.service.WalletService;
import com.ssafy.timo.global.util.Sha256;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

/**
 * 지갑 생성 실패가 회원가입 흐름을 어떻게 끊는지 확인한다. 실제 DB 롤백은 Spring의
 * {@code @Transactional} 자체가 보장하는 영역이라 여기서 다시 증명하지 않고,
 * {@code SignupWalletRollbackIntegrationTest} 가 실제 DB로 그 부분을 확인한다.
 */
@ExtendWith(MockitoExtension.class)
class SignupServiceTest {

    private static final String TICKET = "raw-ticket";
    private static final String PHONE = "01012345678";
    private static final String USERNAME = "timo_user";
    private static final String NICKNAME = "티모";

    @Mock
    private SmsVerificationStore smsVerificationStore;

    @Mock
    private MemberRepository memberRepository;

    @Mock
    private LoginInfoRepository loginInfoRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private AccessTokenProvider accessTokenProvider;

    @Mock
    private RefreshTokenProvider refreshTokenProvider;

    @Mock
    private WalletService walletService;

    @InjectMocks
    private SignupService signupService;

    @Test
    @DisplayName("지갑 생성이 실패하면 예외를 그대로 던지고, 이후 단계(티켓 소비·토큰 발급)는 실행되지 않는다")
    void signUp_propagatesWalletCreationFailure_withoutProceedingFurther() {
        String ticketHash = Sha256.hex(TICKET);
        given(smsVerificationStore.findPhoneNumberByTicket(ticketHash)).willReturn(Optional.of(PHONE));
        given(memberRepository.existsByPhoneNumber(PHONE)).willReturn(false);
        given(memberRepository.existsByNickname(NICKNAME)).willReturn(false);
        given(loginInfoRepository.existsByUsername(USERNAME)).willReturn(false);

        Member savedMember = Member.builder().phoneNumber(PHONE).name("정희성").nickname(NICKNAME).build();
        given(memberRepository.save(any(Member.class))).willReturn(savedMember);

        WalletCryptoException walletFailure = new WalletCryptoException("테스트로 강제한 실패", new RuntimeException());
        given(walletService.createWallet(savedMember)).willThrow(walletFailure);

        assertThatThrownBy(() -> signupService.signUp(request(), "device-1")).isSameAs(walletFailure);

        then(smsVerificationStore).should(never()).deleteTicket(any());
        then(accessTokenProvider).should(never()).issue(any(), any());
        then(refreshTokenProvider).should(never()).issue(any(), any());
    }

    private SignupRequestDto request() {
        return new SignupRequestDto(TICKET, PHONE, "정희성", USERNAME, "timo1234!", NICKNAME);
    }
}
