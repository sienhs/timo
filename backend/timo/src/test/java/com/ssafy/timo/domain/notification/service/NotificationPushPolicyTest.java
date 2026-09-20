package com.ssafy.timo.domain.notification.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.global.config.notification.PushProperties;
import com.ssafy.timo.global.firebase.PushDelivery;
import java.time.Duration;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 알림 종류별 전달 방식이 문서의 표대로인지 본다. 입장만 급하고 나머지는 급하지 않다. */
class NotificationPushPolicyTest {

    private final NotificationPushPolicy policy = new NotificationPushPolicy(
            new PushProperties(new PushProperties.Channel("entry-channel", "general-channel"), 2));

    @Test
    @DisplayName("입장 알림은 높은 우선순위, 유효 시간 2시간, 입장 채널이다")
    void entryOpen_isHighPriorityWithTwoHourTtlOnEntryChannel() {
        PushDelivery delivery = policy.deliveryOf(NotificationType.ENTRY_OPEN);

        assertThat(delivery.priority()).isEqualTo(PushDelivery.Priority.HIGH);
        assertThat(delivery.ttl()).isEqualTo(Duration.ofHours(2));
        assertThat(delivery.channelId()).isEqualTo("entry-channel");
    }

    @Test
    @DisplayName("양도 판매 완료는 높은 우선순위이고 유효 시간은 따로 정하지 않으며 일반 채널이다")
    void listingSold_isHighPriorityWithDefaultTtlOnGeneralChannel() {
        PushDelivery delivery = policy.deliveryOf(NotificationType.LISTING_SOLD);

        assertThat(delivery.priority()).isEqualTo(PushDelivery.Priority.HIGH);
        assertThat(delivery.ttl()).isNull();
        assertThat(delivery.channelId()).isEqualTo("general-channel");
    }

    @Test
    @DisplayName("입장과 판매 완료 외의 알림은 보통 우선순위, 유효 시간 24시간, 일반 채널이다")
    void otherTypes_areNormalPriorityWithDayTtlOnGeneralChannel() {
        for (NotificationType type : NotificationType.values()) {
            if (type == NotificationType.ENTRY_OPEN || type == NotificationType.LISTING_SOLD) {
                continue;
            }
            PushDelivery delivery = policy.deliveryOf(type);

            assertThat(delivery.priority()).as(type.name()).isEqualTo(PushDelivery.Priority.NORMAL);
            assertThat(delivery.ttl()).as(type.name()).isEqualTo(Duration.ofHours(24));
            assertThat(delivery.channelId()).as(type.name()).isEqualTo("general-channel");
        }
    }

    @Test
    @DisplayName("채널 설정이 비어 있으면 채널 없이 나가 앱의 기본 채널로 떨어진다")
    void blankChannel_isSentWithoutChannel() {
        NotificationPushPolicy blank = new NotificationPushPolicy(
                new PushProperties(new PushProperties.Channel("", null), 2));

        assertThat(blank.deliveryOf(NotificationType.ENTRY_OPEN).channelId()).isNull();
        assertThat(blank.deliveryOf(NotificationType.SHOW_REMINDER).channelId()).isNull();
    }
}
