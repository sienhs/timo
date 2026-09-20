package com.ssafy.timo.domain.transfer.service;

import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.notification.service.ListingSoldNotifier;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.dto.PurchaseRequestDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseResponseDto;
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.exception.CannotBuyOwnListingException;
import com.ssafy.timo.domain.transfer.exception.ListingAlreadyClosedException;
import com.ssafy.timo.domain.transfer.exception.ListingNotOpenYetException;
import com.ssafy.timo.domain.transfer.exception.ListingNotFoundException;
import com.ssafy.timo.domain.transfer.exception.ListingPriceMismatchException;
import com.ssafy.timo.domain.transfer.exception.TradePriceExceedsFaceValueException;
import com.ssafy.timo.domain.transfer.exception.TransferFailedException;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;

/**
 * 양도 매물 체결. 선착순이며 응모·추첨·가격제안은 없다.
 *
 * <p>온체인 체결(마켓)은 DB 변경 전에 동기로 부른다 - 실패해도 DB는 그대로라 보상 흐름이
 * 필요 없고, 동시 구매도 체인의 {@code status == LISTED} 조건이 막아 준다.
 *
 * <p>{@code Idempotency-Key}는 형식만 검증하고 저장하지 않는다 - 저장소(Redis)가 아직 없다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PurchaseService {

    private final TicketListingRepository ticketListingRepository;
    private final TicketTradeRepository ticketTradeRepository;
    private final TicketRepository ticketRepository;
    private final MarketHoursService marketHoursService;
    private final ListingSoldNotifier listingSoldNotifier;
    private final TicketTransferService ticketTransferService;
    private final BlockchainProperties blockchainProperties;
    private final Clock clock;

    /**
     * 매물을 산다.
     *
     * <p>처리 순서가 규약의 핵심이다.
     *
     * <ol>
     *   <li>운영 시간인가 → 409</li>
     *   <li>매물이 있는가 → 404, 아직 {@code LISTED} 인가 → 409</li>
     *   <li>마켓에 올라온 매물인가(등록 다음 날 08:00 부터) → 409. 목록에 없어도 번호로 닿을 수 있다</li>
     *   <li>{@code expectedPrice} 가 등록가와 같은가 → 409</li>
     *   <li>내 매물이 아닌가 → 409</li>
     *   <li>등록가가 정가 이하인가(재검증) → 422</li>
     *   <li>티켓이 아직 {@code LISTED} 인가(등록 시 반영된 상태) → 409</li>
     *   <li><b>온체인 체결({@code TicketTransferService.transfer}) - 여기서 실패하면 예외가 그대로
     *       응답을 끝낸다. 아직 DB를 하나도 안 바꿨으므로 롤백할 것도 없다</b></li>
     *   <li>여기까지 왔으면 체인이 확정됐다는 뜻이다. {@code TicketListing}을 {@code SOLD}로,
     *       {@code Ticket}을 {@code markSold()}로, 체결 기록을 {@code CONFIRMED}로 남긴다</li>
     *   <li>판매자에게 판매 완료 알림</li>
     * </ol>
     *
     * <p>2번에서 존재와 상태를 함께 보는 이유는 <b>404와 409를 구분하기 위해서다.</b> 이제
     * {@code markSoldIfListed}로 선점하지 않으므로(8번 이후로 미룸) 읽기만으로 판정할 수 있다.
     * 동시 구매는 더 이상 이 read-check가 아니라 체인이 막는다(클래스 주석 참고) - 두 요청이 동시에
     * 이 지점을 통과해도, 체결 트랜잭션 중 먼저 확정된 쪽만 8번을 통과한다.
     */
    @Transactional
    public PurchaseResponseDto purchase(Long listingId, PurchaseRequestDto request, Long buyerId) {
        marketHoursService.requireOpen();

        LocalDateTime now = LocalDateTime.now(clock);

        // 상세 조회가 공연·공연장·구역을 함께 읽으므로 존재 확인과 겸한다.
        TicketListing listing = ticketListingRepository.findDetailById(listingId)
                .orElseThrow(() -> new ListingNotFoundException(listingId));
        if (listing.getStatus() != ListingStatus.LISTED) {
            throw new ListingAlreadyClosedException(listingId);
        }
        if (!listing.getListedAt().isBefore(marketHoursService.visibleBefore())) {
            throw new ListingNotOpenYetException(listingId, marketHoursService.visibleFrom(listing.getListedAt()));
        }
        if (listing.getPrice() != request.expectedPrice()) {
            // 사용자가 본 금액과 다른 금액이 빠져나가면 안 된다. 실제 가격은 메시지에 담지 않는다 —
            // 남의 매물 가격을 확인하는 경로가 되면 안 된다.
            throw new ListingPriceMismatchException(listingId);
        }
        if (listing.isSeller(buyerId)) {
            throw new CannotBuyOwnListingException(listingId);
        }
        if (listing.getPrice() > listing.getFaceValue()) {
            // 등록 때도 본 검사다. face_value 는 등록 시점 스냅샷이라 불변이므로 정상 경로에서는
            // 도달하지 않는다. 데이터가 손상됐을 때만 걸리는 방어선이고, 그래도 두는 것은 정가 초과
            // 판매 차단이 이 서비스의 존재 이유이기 때문이다.
            throw new TradePriceExceedsFaceValueException(listingId);
        }
        Ticket ticket = ticketRepository.findById(listing.getTicketId())
                .orElseThrow(() -> new ListingAlreadyClosedException(listingId, "티켓이 없다"));
        if (ticket.getStatus() != TicketStatus.LISTED) {
            throw new ListingAlreadyClosedException(listingId, "티켓 상태가 " + ticket.getStatus() + " 다");
        }

        if (blockchainProperties.hasRealAdminPrivateKey()) {
            try {
                ticketTransferService.transfer(
                        listingId, ticket.getId(), listing.getSellerMemberId(), buyerId, listing.getPrice());
            } catch (ContractCallException e) {
                // 원인(revert·일시적 오류)은 사용자에게 알릴 이유가 없는 내부 값이라 로그로만 남긴다.
                // DB는 아직 아무것도 안 바꿨으므로 그냥 실패로 끝내면 된다 - 되돌릴 것도 없다.
                log.warn("양도 체결 실패 (listingId={}, ticketId={})", listingId, ticket.getId(), e);
                throw new TransferFailedException(listingId);
            }
        } else {
            log.debug("체인 미연결 - 양도 체결을 건너뛴다 (listingId={})", listingId);
        }

        if (ticketListingRepository.markSoldIfListed(listingId, now) == 0) {
            // 체인은 확정됐는데 DB가 이미 SOLD가 아니다 - 이론상 있을 수 없다(체인 자체가 동시
            // 체결을 막으므로). 실제로 나면 체인/DB가 어긋난 것이라 그대로 알린다.
            throw new ListingAlreadyClosedException(listingId);
        }
        ticket.markSold();

        TicketTrade trade = TicketTrade.record(listing, buyerId, now);
        trade.confirm();
        trade = ticketTradeRepository.save(trade);

        // 같은 트랜잭션이라 이후 예외가 나면 알림도 함께 사라지고, 푸시는 커밋 뒤에 나간다.
        listingSoldNotifier.notifySold(listing.getSellerMemberId(), trade.getId(), listing.getConcert().getTitle());

        return PurchaseResponseDto.from(trade);
    }
}
