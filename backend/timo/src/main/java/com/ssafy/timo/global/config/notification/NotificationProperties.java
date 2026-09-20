package com.ssafy.timo.global.config.notification;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.ConstructorBinding;
import org.springframework.boot.context.properties.bind.DefaultValue;

import java.time.Duration;

/**
 * 알림 발송 설정.
 *
 * @param sweepLimit 스윕 하나가 한 번의 주기에 새로 저장할 수 있는 알림의 최대 개수. 대상이 이보다 많으면
 *                   남은 것은 다음 주기에 이어서 처리한다. 스윕은 같은 창을 여러 번 훑어도 중복 없이
 *                   이어지도록 만들어져 있어서 나눠 처리해도 결과가 같다. 한 주기가 끝없이 길어져 다음
 *                   주기를 밀어내는 것을 막는 상한이다
 * @param catchUp    놓친 발송을 다시 찾아 주는 보정 구간. 알림을 보내야 하는 시각으로부터 이만큼이 지나도록
 *                   못 보냈어도(배포로 서버가 내려가 있었거나 주기가 밀렸을 때) 이 안에서는 여전히
 *                   보낸다. 이미 보낸 것은 중복 방지가 막으므로 넉넉하게 잡아도 위험이 없다. 다만 너무
 *                   길면 이미 철 지난 알림이 뒤늦게 나간다
 */
@ConfigurationProperties(prefix = "app.notification")
public record NotificationProperties(@DefaultValue("500") int sweepLimit,
                                     @DefaultValue("PT1H") Duration catchUp) {

    /**
     * 설정 바인딩은 이 생성자로 한다. 보조 생성자가 있으면 스프링이 어느 쪽으로 바인딩할지 정하지 못해
     * 애플리케이션이 뜨지 않으므로 명시해야 한다.
     */
    @ConstructorBinding
    public NotificationProperties {
        // 0 이하로 두면 스윕이 아무것도 못 하는데 로그도 남지 않는다. 기동 때 막는다.
        if (sweepLimit <= 0) {
            throw new IllegalArgumentException("app.notification.sweep-limit 은 1 이상이어야 한다: " + sweepLimit);
        }
        if (catchUp == null || catchUp.isZero() || catchUp.isNegative()) {
            throw new IllegalArgumentException("app.notification.catch-up 은 0 보다 커야 한다: " + catchUp);
        }
    }

    /** 보정 구간은 기본값(1시간)을 쓴다. */
    public NotificationProperties(int sweepLimit) {
        this(sweepLimit, Duration.ofHours(1));
    }
}
