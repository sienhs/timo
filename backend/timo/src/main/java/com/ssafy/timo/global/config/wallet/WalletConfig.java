package com.ssafy.timo.global.config.wallet;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 커스터디얼 지갑 설정을 기동 시점에 바인딩·검증하기 위한 진입점.
 *
 * <p>{@link WalletProperties} 를 활성화하는 역할뿐이다.
 * <p>{@code @EnableConfigurationProperties} 가 없으면 Spring 이 이 레코드를 아예 만들지 않아,
 * compact constructor 의 형식 검증이 기동 시점이 아니라 (있지도 않을) 첫 사용 시점까지 미뤄진다.
 */
@Configuration
@EnableConfigurationProperties(WalletProperties.class)
public class WalletConfig {
}
