package com.ssafy.timo.global.config.notification;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 알림 설정({@link NotificationProperties}, {@link NotificationRetentionProperties})을 활성화하는 역할뿐이다.
 * {@code @EnableConfigurationProperties} 가 없으면 이 레코드들은 빈으로 만들어지지 않아 주입받는 쪽이 기동에
 * 실패한다.
 */
@Configuration
@EnableConfigurationProperties({NotificationProperties.class, NotificationRetentionProperties.class})
public class NotificationConfig {
}
