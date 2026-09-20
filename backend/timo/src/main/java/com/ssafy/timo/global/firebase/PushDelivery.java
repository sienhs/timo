package com.ssafy.timo.global.firebase;

import java.time.Duration;
import java.util.Objects;

/**
 * 푸시를 어떻게 전달할지. 무엇을 보내는지({@link PushMessage})와 분리해 둔 이유는 같은 내용도 알림
 * 종류에 따라 급한 정도와 유효 시간이 다르기 때문이다.
 *
 * <p>FCM SDK 타입을 도메인 밖으로 내보내지 않으려고 우선순위와 유효 시간을 여기서 자체 타입으로 받는다.
 *
 * @param priority  {@code HIGH} 는 절전 모드의 기기도 깨운다. 입장처럼 늦으면 소용없는 알림에 쓴다
 * @param ttl       이 시간이 지나도 전달하지 못하면 FCM 이 버린다. null 이면 FCM 기본값을 따른다.
 *                  알림함에 남으므로 버려져도 손실이 아니고, 기기가 꺼져 있던 동안 쌓인 철 지난 푸시가
 *                  한꺼번에 오는 것을 막는다
 * @param channelId 안드로이드 8.0 이상의 알림 채널. 없으면 앱의 기본 채널로 떨어진다. 비어 있는 문자열도
 *                  없는 것으로 본다
 */
public record PushDelivery(Priority priority, Duration ttl, String channelId) {

    /** 개인 발송이 지금까지 하던 대로: 높은 우선순위, 유효 시간과 채널은 지정하지 않는다. */
    public static final PushDelivery DEFAULT = new PushDelivery(Priority.HIGH, null, null);

    public PushDelivery {
        Objects.requireNonNull(priority, "priority");
        if (ttl != null && (ttl.isZero() || ttl.isNegative())) {
            throw new IllegalArgumentException("ttl 은 0 보다 커야 한다: " + ttl);
        }
        channelId = channelId == null || channelId.isBlank() ? null : channelId;
    }

    public enum Priority {
        HIGH,
        NORMAL
    }
}
