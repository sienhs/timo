package com.ssafy.timo.global.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * 알림 보존 설정. 오래된 알림을 지우는 배치가 쓴다.
 *
 * <p>알림은 사용자에게 알리는 부가 메시지이고 분쟁의 근거가 아니다. 거래의 원본은 예매, 양도 체결, 지갑 거래
 * 기록에 따로 남는다. 다만 보존 기간을 정하는 것은 서비스의 개인정보 처리방침이므로 코드에 박지 않고 설정으로
 * 둔다. 더 길게 보관해야 하면 이 값만 바꾸면 된다.
 *
 * @param retentionDays    이 일수가 지난 알림을 지운다. 1 이상이어야 한다
 * @param retentionEnabled false 이면 배치가 아무것도 지우지 않는다
 */
@ConfigurationProperties(prefix = "app.notification")
public record NotificationRetentionProperties(@DefaultValue("90") int retentionDays,
                                              @DefaultValue("true") boolean retentionEnabled) {

    public NotificationRetentionProperties {
        if (retentionDays < 1) {
            throw new IllegalArgumentException(
                    "app.notification.retention-days 는 1 이상이어야 한다: " + retentionDays);
        }
    }
}
