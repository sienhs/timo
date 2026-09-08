package com.ssafy.timo.global.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Clock;
import java.time.ZoneId;

/**
 * 시간을 빈으로 주입해 쓰기 위한 설정.
 *
 * <p>선점 만료처럼 "지금이 언제인가"에 따라 결과가 갈리는 로직은 {@code LocalDateTime.now()} 를
 * 직접 부르면 테스트에서 시간을 고정할 수 없다. {@link Clock} 을 주입받으면 단위 테스트가
 * 고정 시각을 넣어 만료 전후를 모두 검증할 수 있다.
 */
@Configuration
public class ClockConfig {

    @Bean
    public Clock clock() {
        return Clock.system(ZoneId.of("Asia/Seoul"));
    }
}
