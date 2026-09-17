package com.ssafy.timo.support;

import com.ssafy.timo.domain.transfer.service.MarketHoursService;
import com.ssafy.timo.global.config.MarketHoursProperties;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;

/**
 * 운영 시간 판정을 {@link MarketClock} 으로 조립한 {@code MarketHoursService} 를 우선 빈으로 올린다.
 *
 * <p>운영 시간 규칙 자체({@code market.hours})는 실제 값을 그대로 쓴다. 시계만 바꾸는 것이라
 * 테스트가 20:00~23:59:59 창을 실제로 통과하고, 설정을 종일로 열어 두는 우회가 필요 없다.
 * {@link IntegrationTest} 가 함께 올린다.
 */
@TestConfiguration
public class MarketHoursTestConfig {

    @Bean
    public MarketClock marketClock() {
        return new MarketClock();
    }

    @Bean
    @Primary
    public MarketHoursService marketHoursService(MarketHoursProperties properties, MarketClock marketClock) {
        return new MarketHoursService(properties, marketClock);
    }
}
