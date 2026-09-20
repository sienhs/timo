package com.ssafy.timo.global.firebase;

import org.springframework.boot.autoconfigure.condition.ConditionalOnMissingBean;
import org.springframework.stereotype.Component;

import java.util.List;

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

    /** 실제로 보내지 않는다. 지울 토큰이 생기지 않도록 전부 성공으로 돌려준다. */
    @Override
    public List<PushResult> sendEach(List<PushTarget> targets, PushDelivery delivery) {
        return targets.stream().map(target -> PushResult.sent(target.token())).toList();
    }
}
