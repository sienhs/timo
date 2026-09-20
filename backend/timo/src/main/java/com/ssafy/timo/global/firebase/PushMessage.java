package com.ssafy.timo.global.firebase;

import java.util.Map;

/**
 * 도메인 서비스가 보내고 싶은 푸시 내용. FCM SDK 타입을 도메인 밖으로 감춘다.
 *
 * <p>제목이 없다. 본문 하나만 보낸다. 알림함에 저장된 본문과 푸시 본문이 같은 문자열이어야 하고, 여러 줄
 * 본문은 첫 줄이 요약이라 제목 없이도 접힌 푸시에서 뜻이 통한다.
 */
public record PushMessage(String body, Map<String, String> data) {

    public PushMessage {
        data = data == null ? Map.of() : Map.copyOf(data);
    }
}
