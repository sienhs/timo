package com.ssafy.timo.global.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

/**
 * 온체인 정산({@code TicketSettlementService})처럼 "응답은 즉시, 실제 처리는 뒤에서" 가는 작업의
 * 실행기. 기본 {@code SimpleAsyncTaskExecutor}(호출마다 새 스레드)를 그대로 쓰면 체인 트랜잭션이
 * 몰릴 때 스레드가 무한정 늘어나므로, 풀 크기를 고정한 전용 실행기를 둔다.
 */
@Configuration
@EnableAsync
public class AsyncConfig {

    @Bean
    public TaskExecutor onChainSettlementExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(8);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("onchain-settlement-");
        executor.initialize();
        return executor;
    }
}
