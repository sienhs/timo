package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * 입장 처리를 체인에 기록한다.
 *
 * <p>게이트 응답 경로 밖에서 돈다. 입장 줄은 1인당 1초 싸움이라 트랜잭션 확정을 기다릴 여유가
 * 없고, "이 사람이 들어갔다" 의 원본은 DB 다 - 체인은 그 기록이다. 그래서 여기서 실패해도 이미
 * 들여보낸 판정을 되돌리지 않는다.
 *
 * <p>실패가 남는 곳은 로그뿐이다. DB 는 {@code USED} 인데 체인은 {@code OWNED} 로 어긋난 채
 * 남는다는 뜻이라, 공연이 끝난 뒤 기념품 전환({@code convertToSouvenir}) 처럼 체인 상태를
 * 전제하는 작업 전에 한 번 맞춰 줘야 한다. 그 보정은 아직 없다.
 *
 * <p>{@code markUsed} 는 컨트랙트에서 {@code GATE_ROLE} 을 요구한다. 배포 스크립트({@code deploy.ts})가
 * admin 에게 그 역할을 함께 부여하므로 정상 배포된 노드에서는 통과한다 - 그 grant 없이 뜬 노드라면
 * 여기서 AccessControl 로 계속 되돌려진다. 게이트 응답과 DB 는 그 경우에도 정상이고 체인만 안 따라온다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TicketEntryOnChainService {

    private final TicketNftClient ticketNftClient;
    private final BlockchainProperties blockchainProperties;

    /**
     * {@code AFTER_COMMIT} 이라야 한다. 커밋 전에 체인에 먼저 기록하면, 뒤이어 트랜잭션이 롤백됐을 때
     * 되돌릴 수 없는 쪽만 남는다.
     */
    @Async("onChainSettlementExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onTicketEntered(TicketEnteredEvent event) {
        if (!blockchainProperties.hasRealAdminPrivateKey()) {
            // 더미 키로는 시도해 봐야 실패한다 - 방화벽 타임아웃까지 기다리지 않고 곧바로 건너뛴다.
            log.debug("체인 미연결 - 온체인 markUsed 를 건너뛴다 (ticketId={})", event.ticketId());
            return;
        }

        try {
            ticketNftClient.markUsed(event.tokenId());
        } catch (Exception e) {
            log.error("온체인 입장 기록 실패 (ticketId={}, tokenId={})", event.ticketId(), event.tokenId(), e);
        }
    }
}
