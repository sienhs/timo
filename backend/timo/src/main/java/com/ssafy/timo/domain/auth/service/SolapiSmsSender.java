package com.ssafy.timo.domain.auth.service;

import com.solapi.sdk.SolapiClient;
import com.solapi.sdk.message.exception.SolapiMessageNotReceivedException;
import com.solapi.sdk.message.model.Message;
import com.solapi.sdk.message.service.DefaultMessageService;
import com.ssafy.timo.domain.auth.exception.SmsSendFailedException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * 실제로 문자를 보내는 구현체. {@code local} 과 {@code test} 를 제외한 프로파일에서 뜬다.
 *
 * <p>제외하는 이유가 두 가지다. 발송에는 요금이 붙으므로 개발·테스트에서 실제로 나가면 안 되고,
 * {@code solapi.*} 속성이 없는 프로파일에서 이 빈을 만들려 하면 플레이스홀더를 못 찾아
 * <b>기동 자체가 실패</b>한다. 실제로 {@code test} 프로파일에서 이 빈이 떠서 통합 테스트가
 * 전부 컨텍스트 로딩에 실패한 적이 있다.
 *
 * <p>{@link LoggingSmsSender} 와 프로파일 조건이 <b>서로 여집합</b>이어야 한다. 겹치면 빈이 둘,
 * 비면 빈이 없어 어느 쪽이든 기동에 실패한다. 프로파일을 새로 추가할 때는 두 조건을 같이 봐야 한다.
 */
@Slf4j
@Component
@Profile("!local & !test")
public class SolapiSmsSender implements SmsSender {

    private static final String MESSAGE_TEMPLATE = "[TIMO] 인증번호 %s 를 입력해 주세요.";

    private final DefaultMessageService messageService;
    private final String senderPhoneNumber;

    public SolapiSmsSender(@Value("${solapi.api-key}") String apiKey,
                           @Value("${solapi.api-secret}") String apiSecret,
                           @Value("${solapi.sender-phone-number}") String senderPhoneNumber) {
        this.messageService = SolapiClient.INSTANCE.createInstance(apiKey, apiSecret);
        this.senderPhoneNumber = senderPhoneNumber;
    }

    @Override
    public void sendVerificationCode(String phoneNumber, String code) {
        Message message = new Message();
        message.setFrom(senderPhoneNumber);
        message.setTo(phoneNumber);
        message.setText(MESSAGE_TEMPLATE.formatted(code));

        try {
            messageService.send(message);
        } catch (SolapiMessageNotReceivedException e) {
            log.error("SMS send rejected by solapi: phoneNumber={}, failed={}",
                    phoneNumber, e.getFailedMessageList(), e);
            throw new SmsSendFailedException();
        } catch (Exception e) {
            log.error("SMS send failed: phoneNumber={}", phoneNumber, e);
            throw new SmsSendFailedException();
        }
    }
}
