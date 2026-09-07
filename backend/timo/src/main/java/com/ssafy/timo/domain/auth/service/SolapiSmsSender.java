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

@Slf4j
@Component
@Profile("!local")
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
