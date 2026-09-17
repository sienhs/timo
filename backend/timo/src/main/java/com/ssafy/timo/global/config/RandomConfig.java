package com.ssafy.timo.global.config;

import java.util.Random;
import java.util.random.RandomGenerator;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 난수를 빈으로 주입해 쓰기 위한 설정. {@link ClockConfig} 와 같은 이유다.
 *
 * <p>취소표 추첨이 {@code ThreadLocalRandom} 을 직접 부르면 단위 테스트가 "누가 뽑히는지" 를 고정할 수
 * 없다. 시드를 준 {@code Random} 을 넣으면 제외 규칙과 추첨이 재현된다.
 */
@Configuration
public class RandomConfig {

    @Bean
    public RandomGenerator randomGenerator() {
        // getDefault() is backed by the optional jdk.random module. The
        // production JRE does not resolve that module by default, so select a
        // java.base implementation explicitly instead.
        return new Random();
    }
}
