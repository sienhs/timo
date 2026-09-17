package com.ssafy.timo.global.firebase;

import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.stereotype.Component;

/** Firebase 자격증명이 없는 개발·테스트 환경에서 발송 호출을 안전하게 흡수한다. */
@Component
@ConditionalOnMissingBean(FirebasePushNotificationSender.class)
public class NoopPushNotificationSender implements PushNotificationSender {

    @Override
    public String sendToToken(String token, PushMessage message) {
        return "disabled";
    }

    @Override
    public String sendToTopic(String topic, PushMessage message) {
        return "disabled";
    }
}
