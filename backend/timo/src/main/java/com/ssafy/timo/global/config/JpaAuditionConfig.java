package com.ssafy.timo.global.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * JPA Auditing 활성화 설정.
 *
 * <p>{@code @CreatedDate}, {@code @LastModifiedDate} 를 동작시키기 위해 필요하다.
 * 별도 설정 클래스로 분리해 두면 {@code @WebMvcTest} 같은 슬라이스 테스트에서
 * 불필요하게 로딩되지 않는다.
 */
@Configuration
@EnableJpaAuditing
public class JpaAuditionConfig {
}
