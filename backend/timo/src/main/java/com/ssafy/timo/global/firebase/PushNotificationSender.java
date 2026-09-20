package com.ssafy.timo.global.firebase;

import java.util.List;

/**
 * 도메인이 FCM 구현에 묶이지 않도록 둔 발송 포트.
 *
 * <p>예매·양도·공연 리마인더 등은 이 인터페이스만 주입받아 회원 토큰 또는 topic으로 보낸다.
 */
public interface PushNotificationSender {

    String sendToToken(String token, PushMessage message);

    String sendToTopic(String topic, PushMessage message);

    /**
     * 여러 토큰에 각자의 메시지를 보낸다. 개수 제한은 구현이 알아서 나눠 처리하므로 호출부는 얼마든지
     * 넘겨도 된다.
     *
     * <p>발송 실패로 예외를 던지지 않는다. 실패는 토큰별 결과로 돌려주고, 토큰이 더는 쓸 수 없는지
     * ({@link PushResult.Outcome#INVALID_TOKEN}) 와 그 밖의 실패를 구분해 준다. 일시적인 오류는 구현이
     * 먼저 다시 시도하고, 그래도 안 되는 것만 실패로 나온다.
     *
     * @return 요청한 {@code targets} 와 같은 순서, 같은 개수의 결과
     */
    List<PushResult> sendEach(List<PushTarget> targets, PushDelivery delivery);
}
