package com.ssafy.timo.global.config;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * {@code @Scheduled} 잡을 켜는 유일한 지점.
 *
 * <p>스프링 부트는 스케줄링을 자동으로 켜 주지 않는다. 이 설정이 없으면 {@code @Scheduled} 가 붙은
 * 메서드가 아무 말 없이 한 번도 실행되지 않는데, 그건 로그로도 드러나지 않아 찾기 어렵다. 그래서
 * 잡을 새로 붙이는 사람이 여기를 찾을 수 있게 클래스 하나로 모아 둔다.
 *
 * <p>{@code scheduling.enabled} 로 끌 수 있고 테스트 프로파일이 그렇게 한다. 통합 테스트는
 * {@code @Transactional} 롤백으로 서로를 격리하는데, 잡은 별도 스레드에서 자기 트랜잭션으로
 * 커밋하므로 그 격리를 그냥 통과해 다음 테스트로 새어 나간다. 잡이 무엇을 바꾸는지는 타이머를
 * 기다리지 않고 빈을 직접 불러 검증한다({@code ConcertStatusSchedulerTest}).
 */
@Configuration
@EnableScheduling
@ConditionalOnProperty(name = "scheduling.enabled", havingValue = "true", matchIfMissing = true)
public class SchedulingConfig {
}
