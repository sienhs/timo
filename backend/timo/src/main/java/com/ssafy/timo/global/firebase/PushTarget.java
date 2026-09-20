package com.ssafy.timo.global.firebase;

/**
 * 토큰 하나와 그 토큰으로 보낼 메시지. 단체 발송이라도 토큰마다 내용이 다를 수 있어 메시지를 토큰에 묶는다.
 * 알림 id 와 안 읽은 개수는 수신자마다 다른 값이라, 모두에게 같은 메시지를 보내는 방식으로는 못 보낸다.
 */
public record PushTarget(String token, PushMessage message) {
}
