package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyRequestDto;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyResponseDto;
import com.ssafy.timo.domain.ticket.dto.GateRejectReason;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.ticket.service.EntryPassProvider.EntryPassVerification;
import com.ssafy.timo.domain.wallet.entity.Wallet;
import com.ssafy.timo.domain.wallet.repository.WalletRepository;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 게이트 검표. QR 한 장을 받아 들여보낼지 판정하고, 통과시켰다면 그 자리에서 입장 처리까지 끝낸다.
 *
 * <p>판정과 입장 처리를 나누지 않는다. "확인" 과 "소진" 사이에 틈이 있으면 그 틈에 같은 QR 이 다른
 * 게이트에서 한 번 더 통과한다.
 *
 * <p>예외를 던지지 않는다. 거절은 사고가 아니라 정상적인 판정 결과라
 * {@link GateEntryVerifyResponseDto} 로 돌려준다 - 그 이유는 그 DTO 주석 참고.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class GateEntryService {

    private final EntryPassProvider entryPassProvider;
    private final TicketRepository ticketRepository;
    private final WalletRepository walletRepository;
    private final TicketNftClient ticketNftClient;
    private final BlockchainProperties blockchainProperties;
    private final ApplicationEventPublisher eventPublisher;

    /**
     * 검사 순서에 이유가 있다.
     *
     * <ol>
     *   <li>서명·만료 - DB 를 건드리기 전에 우리 QR 인지부터 가린다. 아무 문자열이나 던져 티켓을
     *       조회하게 두지 않는다</li>
     *   <li>공연 일치 - 옆 공연 티켓</li>
     *   <li>상태 - 이미 입장했거나 회수된 티켓을 여기서 걸러 온체인 조회를 아낀다. 다만 이건
     *       빠른 길일 뿐이고, 진짜 보증은 5번이다</li>
     *   <li>온체인 소유자 - <b>소진보다 먼저</b> 본다. 순서가 반대면 소유자 검사에 실패한 스캔이
     *       티켓을 {@code USED} 로 태워, 정당한 소유자가 입장 자체를 못 하게 된다</li>
     *   <li>원자적 소진 - 조건부 UPDATE 가 1을 돌려준 쪽만 통과한다. 게이트가 몇 대든,
     *       3번을 동시에 통과했더라도 여기서 하나로 좁혀진다</li>
     * </ol>
     */
    public GateEntryVerifyResponseDto verify(GateEntryVerifyRequestDto request) {
        EntryPassVerification verification = entryPassProvider.verify(request.qr());
        if (verification.status() == EntryPassVerification.Status.INVALID) {
            return GateEntryVerifyResponseDto.reject(GateRejectReason.INVALID);
        }
        if (verification.status() == EntryPassVerification.Status.EXPIRED) {
            return GateEntryVerifyResponseDto.reject(GateRejectReason.EXPIRED);
        }

        Optional<Ticket> found = ticketRepository.findById(verification.ticketId());
        if (found.isEmpty()) {
            // 우리 서명이 붙었는데 티켓이 없다. 발급한 적 없는 조합이거나 행이 지워진 것이다.
            log.warn("서명은 유효한데 티켓이 없다 (ticketId={})", verification.ticketId());
            return GateEntryVerifyResponseDto.reject(GateRejectReason.INVALID);
        }
        Ticket ticket = found.get();

        if (!ticket.getReservation().getConcert().getId().equals(request.concertId())) {
            return GateEntryVerifyResponseDto.reject(GateRejectReason.WRONG_CONCERT);
        }

        if (ticket.getStatus() != TicketStatus.OWNED) {
            return GateEntryVerifyResponseDto.reject(reasonFor(ticket.getStatus()));
        }

        GateRejectReason ownershipProblem = verifyOnChainOwner(ticket);
        if (ownershipProblem != null) {
            return GateEntryVerifyResponseDto.reject(ownershipProblem);
        }

        if (ticketRepository.markUsedIfOwned(ticket.getId()) == 0) {
            // 3번을 통과한 뒤 다른 게이트가 먼저 소진했다. 지금 상태를 다시 읽어 사유를 가린다.
            TicketStatus current = ticketRepository.findById(ticket.getId())
                    .map(Ticket::getStatus)
                    .orElse(TicketStatus.USED);
            return GateEntryVerifyResponseDto.reject(reasonFor(current));
        }

        eventPublisher.publishEvent(new TicketEnteredEvent(ticket.getId(), ticket.getTokenId()));
        return GateEntryVerifyResponseDto.admit();
    }

    /**
     * 온체인 현재 소유자와 맞는지 본다. 통과면 {@code null}.
     *
     * <p>{@code Ticket.tokenId} 는 DB 캐시라 그대로 믿으면 안 된다는 것이 이 도메인의 전제다
     * ({@code Ticket} 주석). 양도가 끝난 직후라면 DB 는 아직 예전 소유자를 가리킬 수 있어, 입장처럼
     * 되돌릴 수 없는 처리 직전에는 체인에 다시 묻는다.
     *
     * <p>체인이 준비되지 않은 환경에서는 건너뛴다. 로컬·테스트는 admin 키가 더미라 RPC 에 닿지
     * 못하는데, 그때 이 검사를 강행하면 <b>모든 스캔이 거절</b>되어 게이트를 아예 띄워 볼 수 없다.
     * 판정 기준이 환경마다 달라지는 셈이라 편한 선택은 아니지만, 대안은 로컬에서 입장 흐름을
     * 전혀 못 보는 것이다. 시더가 {@code hasRealAdminPrivateKey} 로 온체인 등록을 건너뛰는 것과
     * 같은 관용구를 따른다.
     *
     * <p>체인에는 닿았는데 호출이 실패한 경우는 통과시키지 않는다. 확인하지 못한 것을 확인된 것으로
     * 다루면 안 되고, 관람객은 다시 찍으면 된다.
     */
    private GateRejectReason verifyOnChainOwner(Ticket ticket) {
        if (!blockchainProperties.hasRealAdminPrivateKey()) {
            return null;
        }

        Optional<Wallet> wallet = walletRepository.findById(ticket.getReservation().getMember().getId());
        if (wallet.isEmpty()) {
            log.warn("티켓 소유자의 지갑이 없다 (ticketId={})", ticket.getId());
            return GateRejectReason.SIGNATURE_MISMATCH;
        }

        try {
            String onChainOwner = ticketNftClient.ownerOf(ticket.getTokenId());
            if (!onChainOwner.equalsIgnoreCase(wallet.get().getAddress())) {
                return GateRejectReason.SIGNATURE_MISMATCH;
            }
            return null;
        } catch (ContractCallException e) {
            log.error("온체인 소유자 조회 실패 (ticketId={}, tokenId={})", ticket.getId(), ticket.getTokenId(), e);
            return GateRejectReason.SIGNATURE_MISMATCH;
        }
    }

    /** 통과하지 못한 상태를 게이트가 아는 사유로 옮긴다. */
    private GateRejectReason reasonFor(TicketStatus status) {
        return switch (status) {
            case USED -> GateRejectReason.ALREADY_USED;
            case REVOKED -> GateRejectReason.REVOKED;
            // 발행 전(PENDING_MINT)·실패(MINT_FAILED)·환불(REFUNDED)·양도 등록 중(LISTED).
            // 관람객에게 굳이 내부 진행 상태를 알려줄 이유가 없어 하나로 묶는다.
            default -> GateRejectReason.INVALID;
        };
    }
}
