package com.ssafy.timo.domain.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.auth.repository.SmsVerificationStore;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.wallet.crypto.CustodialWalletCrypto;
import com.ssafy.timo.domain.wallet.crypto.WalletCryptoException;
import com.ssafy.timo.global.util.Sha256;
import java.time.Duration;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 지갑 생성이 실패하면 회원가입 전체가 실제 DB에서 롤백되는지 확인한다.
 *
 * <p>{@code @IntegrationTest}는 {@code @MockitoBean}을 금지해서 못 쓴다. (공유 컨텍스트 오염 방지)
 * <p>{@link CustodialWalletCrypto}를 실패하도록 바꿔치기해야 하므로 이 클래스만 별도 컨텍스트를 새로 띄운다.
 *
 * 테스트에 {@code @Transactional}도 안 붙인다.
 * 붙이면 {@code signUp()}의 트랜잭션이 거기 합류해서 운영과 다른 모양이 된다.
 */
@SpringBootTest
@AutoConfigureMockMvc(addFilters = false)
@ActiveProfiles("test")
class SignupWalletRollbackIntegrationTest {

    private static final String SIGNUP_PATH = "/api/v1/auth/signup";
    private static final String DEVICE_ID_HEADER = "X-Device-Id";
    private static final String DEVICE_ID = "22222222-2222-2222-2222-222222222222";
    private static final String PHONE = "01055556666";

    @MockitoBean
    private CustodialWalletCrypto custodialWalletCrypto;

    @Autowired
    private MockMvc mvc;

    @Autowired
    private SmsVerificationStore smsVerificationStore;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private LoginInfoRepository loginInfoRepository;

    @Test
    @DisplayName("지갑 생성이 실패하면 회원·로그인 수단도 DB에 남지 않는다")
    void signUp_rollsBackMemberAndLoginInfo_whenWalletCreationFails() throws Exception {
        given(custodialWalletCrypto.create())
                .willThrow(new WalletCryptoException("테스트로 강제한 실패", new RuntimeException("boom")));
        String ticket = issueTicket(PHONE);

        mvc.perform(post(SIGNUP_PATH)
                        .header(DEVICE_ID_HEADER, DEVICE_ID)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body(ticket)))
                .andExpect(status().isInternalServerError());

        assertThat(memberRepository.existsByPhoneNumber(PHONE)).isFalse();
        assertThat(loginInfoRepository.existsByUsername("wallet_fail_user")).isFalse();
    }

    private String issueTicket(String phoneNumber) {
        String ticket = UUID.randomUUID().toString();
        smsVerificationStore.saveTicket(Sha256.hex(ticket), phoneNumber, Duration.ofMinutes(30));
        return ticket;
    }

    private String body(String ticket) {
        return """
                {
                  "verificationTicket": "%s",
                  "phoneNumber": "%s",
                  "name": "정희성",
                  "username": "wallet_fail_user",
                  "password": "timo1234!",
                  "nickname": "지갑실패테스트"
                }
                """.formatted(ticket, PHONE);
    }
}
