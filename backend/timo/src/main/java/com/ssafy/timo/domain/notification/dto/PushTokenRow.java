package com.ssafy.timo.domain.notification.dto;

/**
 * 회원과 그 회원이 가진 FCM 토큰 한 건. 여러 회원의 토큰을 한 번에 읽으면서 토큰이 누구 것인지 함께
 * 알아야 하는데, 엔티티를 읽으면 회원이 지연 로딩이라 세션 밖에서 접근할 수 없다.
 */
public interface PushTokenRow {

    Long getMemberId();

    String getToken();
}
