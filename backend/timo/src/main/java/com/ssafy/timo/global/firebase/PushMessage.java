package com.ssafy.timo.global.firebase;

import java.util.Map;

/** 도메인 서비스가 보내고 싶은 푸시 내용. FCM SDK 타입을 도메인 밖으로 감춘다. */
public record PushMessage(String title, String body, Map<String, String> data) {

    public PushMessage {
        data = data == null ? Map.of() : Map.copyOf(data);
    }
}
