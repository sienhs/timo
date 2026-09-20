package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.global.config.NotificationProperties;
import com.ssafy.timo.global.config.NotificationRetentionProperties;
import com.ssafy.timo.global.config.PushProperties;
import com.ssafy.timo.support.IntegrationTest;
import java.io.IOException;
import java.time.Duration;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.env.Environment;
import org.springframework.core.env.MapPropertySource;
import org.springframework.core.env.PropertySource;
import org.springframework.core.env.StandardEnvironment;
import org.springframework.core.io.ClassPathResource;

/**
 * 알림 설정값이 {@code application.yml} 에 실제로 적혀 있고 코드가 그것을 읽는지 확인한다.
 *
 * <p>값이 코드의 기본값과 같아서, 바인딩된 빈만 보면 yml 에 적혔는지 기본값을 쓴 것인지 구별되지 않는다.
 * 그래서 환경에서 키를 직접 읽어 yml 에 있는지 본다. 채널은 환경변수 이름이 틀리면 조용히 아무 일도 안 일어나므로,
 * 환경변수를 넣었을 때 실제로 채널 값이 되는지도 본다.
 */
@IntegrationTest
class NotificationSettingsTest {

    @Autowired
    private Environment environment;

    @Autowired
    private NotificationProperties notificationProperties;

    @Autowired
    private NotificationRetentionProperties retentionProperties;

    @Autowired
    private PushProperties pushProperties;

    @Test
    @DisplayName("스윕과 보존 설정이 yml 에 적혀 있다")
    void notificationSettings_areWrittenInYaml() {
        assertThat(environment.getProperty("app.notification.sweep-limit")).isEqualTo("500");
        assertThat(environment.getProperty("app.notification.catch-up")).isEqualTo("PT1H");
        assertThat(environment.getProperty("app.notification.retention-days")).isEqualTo("90");
        assertThat(environment.getProperty("app.notification.retention-enabled")).isEqualTo("true");
    }

    @Test
    @DisplayName("푸시 설정이 yml 에 적혀 있고 채널은 환경변수가 없으면 빈 값이다")
    void pushSettings_areWrittenInYaml_withEmptyChannelsByDefault() {
        assertThat(environment.getProperty("app.push.retry")).isEqualTo("2");
        // 키가 없으면 null 이고, 키가 있는데 값이 비면 빈 문자열이다. yml 에 키가 있는지를 가른다.
        assertThat(environment.getProperty("app.push.channel.entry")).isEqualTo("");
        assertThat(environment.getProperty("app.push.channel.general")).isEqualTo("");
    }

    @Test
    @DisplayName("코드가 읽은 값이 문서에 적힌 값과 같다")
    void boundProperties_matchDocumentedValues() {
        assertThat(notificationProperties.sweepLimit()).isEqualTo(500);
        assertThat(notificationProperties.catchUp()).isEqualTo(Duration.ofHours(1));
        assertThat(retentionProperties.retentionDays()).isEqualTo(90);
        assertThat(retentionProperties.retentionEnabled()).isTrue();
        assertThat(pushProperties.retry()).isEqualTo(2);
        assertThat(pushProperties.channel().entry()).isNullOrEmpty();
        assertThat(pushProperties.channel().general()).isNullOrEmpty();
    }

    @Test
    @DisplayName("PUSH_CHANNEL_ENTRY 와 PUSH_CHANNEL_GENERAL 환경변수가 각각 입장과 일반 채널이 된다")
    void channelEnvironmentVariables_mapToChannels() throws IOException {
        StandardEnvironment env = new StandardEnvironment();
        for (PropertySource<?> source : new YamlPropertySourceLoader()
                .load("application", new ClassPathResource("application.yml"))) {
            env.getPropertySources().addLast(source);
        }
        env.getPropertySources().addFirst(new MapPropertySource("fake-os-env", Map.of(
                "PUSH_CHANNEL_ENTRY", "entry-alerts",
                "PUSH_CHANNEL_GENERAL", "general-alerts")));

        assertThat(env.getProperty("app.push.channel.entry")).isEqualTo("entry-alerts");
        assertThat(env.getProperty("app.push.channel.general")).isEqualTo("general-alerts");
    }
}
