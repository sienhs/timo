package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.global.config.PushProperties;
import com.ssafy.timo.global.firebase.PushDelivery;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.Duration;

/**
 * 알림 종류에 따라 푸시를 어떻게 전달할지 정한다.
 *
 * <p>입장 알림은 공연 시작 두 시간 전에 나가서 늦으면 소용이 없다. 그래서 높은 우선순위로 보내 절전
 * 모드의 기기도 깨우고, 유효 시간을 두 시간으로 줄여 입장 시간이 지난 뒤에 도착하지 않게 한다. 나머지는
 * 급하지 않아 보통 우선순위이고, 기기가 하루 동안 꺼져 있다 켜졌을 때 철 지난 푸시가 몰려오지 않도록
 * 유효 시간을 하루로 둔다. 버려진 푸시는 알림함에 남아 있어 손실이 아니다.
 *
 * <p>양도 판매 완료도 높은 우선순위로 보낸다. 판매자가 돈이 오간 결과를 바로 확인해야 하는 알림이기 때문이다.
 * 다만 유효 시간은 입장처럼 촉박하지 않아 따로 정하지 않고 FCM 기본값을 따른다.
 */
@Component
@RequiredArgsConstructor
public class NotificationPushPolicy {

    static final Duration ENTRY_TTL = Duration.ofHours(2);
    static final Duration GENERAL_TTL = Duration.ofHours(24);

    private final PushProperties properties;

    public PushDelivery deliveryOf(NotificationType type) {
        return switch (type) {
            case ENTRY_OPEN -> new PushDelivery(
                    PushDelivery.Priority.HIGH, ENTRY_TTL, properties.channel().entry());
            case LISTING_SOLD -> new PushDelivery(
                    PushDelivery.Priority.HIGH, null, properties.channel().general());
            default -> new PushDelivery(
                    PushDelivery.Priority.NORMAL, GENERAL_TTL, properties.channel().general());
        };
    }
}
