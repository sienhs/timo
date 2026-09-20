package com.ssafy.timo.global.config.notification;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * 푸시 발송 설정.
 *
 * <p>알림 채널은 앱이 만든 것을 서버가 이름으로 가리킨다. 이름을 소스에 박지 않고 설정으로 뺀 이유는 앱의
 * 결정이 늦어져도 서버가 막히지 않게 하려는 것이다. 값이 비어 있으면 채널을 싣지 않아 앱의 기본 채널로
 * 떨어진다. 다만 앱이 만들지 않은 채널 이름을 넣으면 안드로이드 8.0 이상에서는 알림이 표시되지 않고
 * 예외도 로그도 남지 않는다.
 *
 * @param channel 알림 종류별 채널 이름
 * @param retry   일시적으로 실패한 발송을 다시 시도하는 횟수. 처음 시도는 세지 않는다
 */
@ConfigurationProperties(prefix = "app.push")
public record PushProperties(@DefaultValue Channel channel, @DefaultValue("2") int retry) {

    /**
     * @param entry   입장 알림. 시간이 급해 다른 알림과 소리·진동을 다르게 줄 수 있다
     * @param general 그 밖의 알림
     */
    public record Channel(String entry, String general) {
    }
}
