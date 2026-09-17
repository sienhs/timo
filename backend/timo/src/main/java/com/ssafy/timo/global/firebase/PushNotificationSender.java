package com.ssafy.timo.global.firebase;

/**
 * 도메인이 FCM 구현에 묶이지 않도록 둔 발송 포트.
 *
 * <p>예매·양도·공연 리마인더 등은 이 인터페이스만 주입받아 회원 토큰 또는 topic으로 보낸다.
 */
public interface PushNotificationSender {

    String sendToToken(String token, PushMessage message);

    String sendToTopic(String topic, PushMessage message);
}
