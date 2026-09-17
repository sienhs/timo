package com.ssafy.timo.global.firebase;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.Notification;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

/** Firebase Admin SDK를 통한 실제 FCM 발송 구현. */
@Primary
@Component
@ConditionalOnProperty(prefix = "app.firebase", name = "messaging-enabled", havingValue = "true")
@RequiredArgsConstructor
public class FirebasePushNotificationSender implements PushNotificationSender {

    private final FirebaseApp firebaseApp;

    @Override
    public String sendToToken(String token, PushMessage message) {
        return send(build(message).setToken(token).build());
    }

    @Override
    public String sendToTopic(String topic, PushMessage message) {
        return send(build(message).setTopic(topic).build());
    }

    private Message.Builder build(PushMessage message) {
        return Message.builder()
                .setNotification(Notification.builder().setTitle(message.title()).setBody(message.body()).build())
                .putAllData(message.data())
                .setAndroidConfig(AndroidConfig.builder().setPriority(AndroidConfig.Priority.HIGH).build());
    }

    private String send(Message message) {
        try {
            return FirebaseMessaging.getInstance(firebaseApp).send(message);
        } catch (Exception e) {
            throw new IllegalStateException("FCM 메시지 발송에 실패했습니다.", e);
        }
    }
}
