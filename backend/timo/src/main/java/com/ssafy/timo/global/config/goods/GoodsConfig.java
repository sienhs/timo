package com.ssafy.timo.global.config.goods;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Configuration;

/**
 * 굿즈 설정을 켜는 자리. {@code @EnableConfigurationProperties} 가 없으면 이 레코드는 빈으로
 * 만들어지지 않아 주입받는 쪽이 기동에 실패한다.
 */
@Configuration
@EnableConfigurationProperties(GoodsUploadProperties.class)
public class GoodsConfig {
}
