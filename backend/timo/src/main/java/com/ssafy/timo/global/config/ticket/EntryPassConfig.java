package com.ssafy.timo.global.config.ticket;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 입장 QR 설정을 기동 시점에 바인딩·검증하기 위한 진입점.
 *
 * <p>{@link EntryPassProperties} 를 활성화하는 역할뿐이다. {@code @EnableConfigurationProperties}
 * 가 없으면 Spring 이 레코드를 아예 만들지 않아, compact constructor 의 키 길이 검증이 기동
 * 시점이 아니라 첫 발급 요청까지 미뤄진다.
 */
@Configuration
@EnableConfigurationProperties(EntryPassProperties.class)
public class EntryPassConfig {
}
