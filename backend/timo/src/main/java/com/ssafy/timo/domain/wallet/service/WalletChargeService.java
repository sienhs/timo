package com.ssafy.timo.domain.wallet.service;

import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.blockchain.ContractClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.wallet.dto.WalletSummaryResponseDto;
import com.ssafy.timo.domain.wallet.dto.WalletTransactionResponseDto;
import com.ssafy.timo.domain.wallet.entity.WalletTransaction;
import com.ssafy.timo.domain.wallet.exception.WalletChargeFailedException;
import com.ssafy.timo.domain.wallet.repository.WalletTransactionRepository;
import java.math.BigInteger;
import java.util.List;
import java.util.NoSuchElementException;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 회원 지갑의 잔액 조회·충전. 실제 PG 연동 전까지는 "결제가 이미 확인됐다" 고 가정하고 곧바로
 * {@code TicketVault}에 반영한다({@code 요구사항 #21}이 PG 모의 연동이다).
 *
 * <p>잔액의 유일한 진실은 체인({@code TicketVault.balanceOf})이다. {@link WalletTransaction}은
 * 화면의 사용 내역을 보여주기 위한 오프체인 이력일 뿐이라, 체인 반영이 끝난 뒤에 그 결과(반영 후
 * 잔액)를 그대로 기록한다 - 스스로 잔액을 계산해서 적지 않는다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class WalletChargeService {

    private static final int RECENT_TRANSACTION_LIMIT = 20;
    private static final String CHARGE_TITLE = "머쉬룸 충전";
    private static final String MOCK_PG_SOURCE = "PG 모의 결제";

    private final MemberRepository memberRepository;
    private final WalletService walletService;
    private final WalletTransactionRepository walletTransactionRepository;
    private final TicketVaultClient ticketVaultClient;

    @Transactional(readOnly = true)
    public WalletSummaryResponseDto getSummary(Long memberId) {
        String address = walletService.getAddress(memberId);
        long balance = ticketVaultClient.balanceOf(address).longValueExact();

        return new WalletSummaryResponseDto(balance, recentTransactionsOf(memberId));
    }

    /** 마치 PG가 이미 결제를 확인해 준 것처럼, 곧바로 체인에 충전을 반영한다. */
    public WalletSummaryResponseDto charge(Long memberId, long amount) {
        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new NoSuchElementException("회원을 찾을 수 없습니다 (memberId=" + memberId + ")"));
        String address = walletService.getAddress(memberId);
        BigInteger chargeAmount = BigInteger.valueOf(amount);

        byte[] refId = ContractClient.keccak256("wallet-charge-" + UUID.randomUUID());
        try {
            ticketVaultClient.deposit(address, chargeAmount, refId);
        } catch (ContractCallException e) {
            // 아직 아무 것도 저장되지 않은 시점이라 그냥 다시 시도하면 된다.
            log.warn("지갑 충전 - 온체인 반영 실패 (memberId={})", memberId, e);
            throw new WalletChargeFailedException(e);
        }
        BigInteger balanceAfter = ticketVaultClient.balanceOf(address);

        walletTransactionRepository.save(WalletTransaction.builder()
                .member(member)
                .title(CHARGE_TITLE)
                .amount(chargeAmount)
                .balanceAfter(balanceAfter)
                .source(MOCK_PG_SOURCE)
                .build());

        return new WalletSummaryResponseDto(balanceAfter.longValueExact(), recentTransactionsOf(memberId));
    }

    private List<WalletTransactionResponseDto> recentTransactionsOf(Long memberId) {
        return walletTransactionRepository
                .findAllByMemberIdOrderByCreatedAtDescIdDesc(memberId, PageRequest.of(0, RECENT_TRANSACTION_LIMIT))
                .stream()
                .map(WalletTransactionResponseDto::from)
                .toList();
    }
}
