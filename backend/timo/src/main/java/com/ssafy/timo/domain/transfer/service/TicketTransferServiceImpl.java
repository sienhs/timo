package com.ssafy.timo.domain.transfer.service;

import com.ssafy.timo.domain.blockchain.ContractClient;
import com.ssafy.timo.domain.blockchain.MarketplaceClient;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.exception.TicketNotFoundException;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.wallet.service.WalletService;

import java.math.BigInteger;

import org.springframework.stereotype.Service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * {@link TicketTransferService}의 실제 구현. {@link MarketplaceClient#buy}를 부르는 얇은 어댑터다.
 *
 * <p>{@code sellerMemberId}는 {@code buy} 호출 자체엔 안 쓰인다(컨트랙트가 {@code ownerOf}로 직접
 * 판매자를 구한다) - 실패 로그에서 어느 쪽 체결이었는지 알아볼 수 있게 남겨 둔다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TicketTransferServiceImpl implements TicketTransferService {

    private final MarketplaceClient marketplaceClient;
    private final TicketRepository ticketRepository;
    private final WalletService walletService;

    @Override
    public TransferResult transfer(long listingId, long ticketId, long sellerMemberId, long buyerMemberId, long price) {
        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new TicketNotFoundException(ticketId));
        String buyerAddress = walletService.getAddress(buyerMemberId);
        byte[] tradeId = ContractClient.keccak256("listing-" + listingId);

        log.debug("양도 체결 시도 (listingId={}, ticketId={}, sellerMemberId={}, buyerMemberId={}, price={})",
                listingId, ticketId, sellerMemberId, buyerMemberId, price);
        String txHash = marketplaceClient.buy(ticket.getTokenId(), buyerAddress, tradeId);
        return new TransferResult(txHash);
    }
}
