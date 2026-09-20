package com.ssafy.timo.global.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.task.TaskExecutor;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor;

import java.util.concurrent.ThreadPoolExecutor;

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

    /**
     * 알림 푸시 발송 실행기. 온체인 정산과 섞지 않는다. 정산은 오래 걸려 푸시가 그 뒤에서 기다리게 되고,
     * 푸시가 몰리면 정산이 밀리기 때문이다.
     *
     * <p>큐가 차면 예외를 던지지 않고 호출한 스레드가 직접 보낸다. 이 실행기는 커밋 직후에 불리는데, 거기서
     * 던진 예외는 이미 커밋된 결제나 스윕의 결과처럼 보이게 되므로 거절이 예외가 되어서는 안 된다. 직접
     * 보내면 호출 스레드가 잠시 느려질 뿐 알림은 잃지 않는다.
     *
     * <p>종료할 때는 밀린 발송을 잠시 기다린다. 배포 중에 큐에 있던 푸시가 사라지지 않게 하려는 것이다.
     * 사라져도 알림함에는 남아 있다.
     */
    @Bean
    public TaskExecutor pushExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(2);
        executor.setMaxPoolSize(4);
        executor.setQueueCapacity(200);
        executor.setThreadNamePrefix("push-");
        executor.setRejectedExecutionHandler(new ThreadPoolExecutor.CallerRunsPolicy());
        executor.setWaitForTasksToCompleteOnShutdown(true);
        executor.setAwaitTerminationSeconds(10);
        executor.initialize();
        return executor;
    }
}
