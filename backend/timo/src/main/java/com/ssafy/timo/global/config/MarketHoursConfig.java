package com.ssafy.timo.global.config;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 양도 마켓 운영 시간 설정을 기동 시점에 바인딩·검증하기 위한 진입점.
 *
 * <p>{@link MarketHoursProperties} 를 활성화하는 역할뿐이다. 이것이 없으면 Spring 이 레코드를
 * 만들지 않아 compact constructor 의 검증이 첫 마켓 요청까지 미뤄진다({@code EntryPassConfig} 와 같다).
 */
@Configuration
@EnableConfigurationProperties(MarketHoursProperties.class)
public class MarketHoursConfig {
}
