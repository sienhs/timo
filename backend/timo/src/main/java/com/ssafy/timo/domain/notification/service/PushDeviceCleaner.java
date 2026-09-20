package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.repository.PushDeviceRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;

/**
 * FCM 이 죽었다고 알려 준 토큰을 지운다.
 *
 * <p>별도 빈으로 뺀 이유가 있다. 푸시는 업무 트랜잭션이 커밋된 뒤에 보내는데, 그 시점의 코드는 이미 끝난
 * 트랜잭션에 걸려 있어 거기서 지운 것은 커밋되지 않고 사라진다. 그래서 항상 새 트랜잭션을 열어야 하고,
 * 같은 클래스 안에서 부르면 프록시를 거치지 않아 새 트랜잭션이 열리지 않으므로 다른 빈이어야 한다.
 */
@Component
@RequiredArgsConstructor
public class PushDeviceCleaner {

    private final PushDeviceRepository pushDeviceRepository;

    /** @return 실제로 지워진 개수 */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public int deleteByTokens(Collection<String> tokens) {
        if (tokens.isEmpty()) {
            return 0;
        }
        return pushDeviceRepository.deleteAllByTokenIn(tokens);
    }
}
