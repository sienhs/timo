package com.ssafy.timo.domain.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.auth.repository.SmsVerificationStore;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * 인증번호 발송 API 통합 테스트.
 *
 * <p>{@code SmsVerificationStore} 는 인메모리 싱글턴이라 <b>테스트 롤백에 걸리지 않는다.</b>
 * 쿨다운과 횟수가 다음 테스트로 넘어가므로 테스트마다 다른 번호를 쓴다. IP 제한은
 * MockMvc 가 모두 {@code 127.0.0.1} 로 오기 때문에 이 클래스 전체가 한 시간 20회를 나눠 쓴다.
 */
@IntegrationTest
class SmsSendApiIntegrationTest {

    private static final String SEND_PATH = "/api/v1/auth/sms/send";

    private static final String FRESH_PHONE = "01020001111";
    private static final String TAKEN_PHONE = "01020002222";
    private static final String TAKEN_PHONE_FOR_COOLDOWN = "01020003333";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private SmsVerificationStore smsVerificationStore;

    @Test
    @DisplayName("가입되지 않은 번호면 200 과 유효시간을 반환한다")
    void sendCode_returnsExpiryForFreshNumber() throws Exception {
        mvc.perform(sendRequest(FRESH_PHONE))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.expiresInSeconds").value(180));

        assertThat(smsVerificationStore.findCodeHash(FRESH_PHONE)).isPresent();
    }

    @Test
    @DisplayName("이미 가입된 번호면 409 를 반환하고 인증번호를 만들지 않는다")
    void sendCode_rejectsRegisteredNumber() throws Exception {
        saveMember(TAKEN_PHONE, "이미가입");

        // 도메인 예외에는 errorCode 가 실리지 않는다(AuthExceptionHandler 만 넣는다).
        // 앱은 이 경로의 409 하나로 판단해야 하므로 상태 코드와 exception 을 함께 고정해 둔다.
        mvc.perform(sendRequest(TAKEN_PHONE))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.exception").value("PhoneNumberDuplicatedException"))
                .andExpect(jsonPath("$.errorMessage").value("이미 가입된 전화번호입니다."));

        // 인증번호가 저장되지 않았다는 것이 곧 문자를 보내지 않았다는 뜻이다.
        // 발송과 저장이 붙어 있어 하나만 일어날 수 없다.
        assertThat(smsVerificationStore.findCodeHash(TAKEN_PHONE)).isEmpty();
    }

    @Test
    @DisplayName("가입된 번호로 거절돼도 발송 제한은 이미 소모된다")
    void sendCode_consumesSendLimitBeforeDuplicateCheck() throws Exception {
        saveMember(TAKEN_PHONE_FOR_COOLDOWN, "쿨다운");

        mvc.perform(sendRequest(TAKEN_PHONE_FOR_COOLDOWN))
                .andExpect(status().isConflict());

        // 중복 검사가 제한 검사보다 앞에 있으면 여기도 409 다. 429 여야 순서가 맞다.
        // 그래야 이 응답으로 가입 여부를 긁는 것이 쿨다운과 횟수에 함께 걸린다.
        mvc.perform(sendRequest(TAKEN_PHONE_FOR_COOLDOWN))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.exception").value("SmsSendLimitExceededException"));
    }

    private void saveMember(String phoneNumber, String nickname) {
        memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber)
                .name("정희성")
                .nickname(nickname)
                .build());
    }

    private MockHttpServletRequestBuilder sendRequest(String phoneNumber) {
        return post(SEND_PATH)
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                        {
                          "phoneNumber": "%s"
                        }
                        """.formatted(phoneNumber));
    }
}
