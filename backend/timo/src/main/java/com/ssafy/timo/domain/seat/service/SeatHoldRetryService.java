package com.ssafy.timo.domain.seat.service;

import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * InnoDB deadlock은 충돌 감지가 트랜잭션 하나를 롤백해 해결한다. 서로 다른 좌석에도 드물게
 * 생길 수 있으므로, 전체 선점 트랜잭션을 새로 열어 짧게 재시도한다.
 */
@Service
@RequiredArgsConstructor
public class SeatHoldRetryService {

    private static final int MAX_ATTEMPTS = 3;

    private final SeatService seatService;
    private final PlatformTransactionManager transactionManager;

    public SeatHoldResponseDto hold(Long memberId, Long concertId, Long seatId) {
        CannotAcquireLockException lastFailure = null;
        for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
            try {
                return new TransactionTemplate(transactionManager)
                        .execute(status -> seatService.hold(memberId, concertId, seatId));
            } catch (CannotAcquireLockException failure) {
                lastFailure = failure;
                pauseBeforeRetry(attempt);
            }
        }
        throw lastFailure;
    }

    private void pauseBeforeRetry(int attempt) {
        try {
            Thread.sleep(10L << attempt);
        } catch (InterruptedException interruption) {
            Thread.currentThread().interrupt();
            throw new CannotAcquireLockException("Interrupted while retrying seat hold", interruption);
        }
    }
}
