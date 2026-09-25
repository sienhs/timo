package com.ssafy.timo.global.firebase;

import java.util.Map;

/**
 * 도메인 서비스가 보내고 싶은 푸시 내용. FCM SDK 타입을 도메인 밖으로 감춘다.
 *
 * <p>제목이 없다. 본문 하나만 보낸다. 알림함에 저장된 본문과 푸시 본문이 같은 문자열이어야 하고, 여러 줄
 * 본문은 첫 줄이 요약이라 제목 없이도 접힌 푸시에서 뜻이 통한다.
 *
 * <p>본문이 null 이면 배너 없는 조용한 푸시다({@link #silent}). 기기에 아무것도 띄우지 않고 앱에
 * {@code data} 만 전달해, 알림함에 남길 일이 아닌 화면 갱신 신호에 쓴다.
 */
public record PushMessage(String body, Map<String, String> data) {

    public PushMessage {
        data = data == null ? Map.of() : Map.copyOf(data);
    }

    /** 본문 없이 {@code data} 만 보내는 조용한 푸시. 값은 FCM 제약상 전부 문자열이어야 한다. */
    public static PushMessage silent(Map<String, String> data) {
        return new PushMessage(null, data);
    }

    public boolean isSilent() {
        return body == null;
    }
}
