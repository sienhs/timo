package com.ssafy.timo.domain.transfer.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.notification.service.ListingSoldNotifier;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.ticket.service.TicketOwnershipService;
import com.ssafy.timo.domain.ticket.service.TicketOwnershipWriter;
import com.ssafy.timo.domain.wallet.service.WalletService;
import com.ssafy.timo.domain.transfer.dto.CreateListingRequestDto;
import com.ssafy.timo.domain.transfer.dto.MarketListRequestDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseRequestDto;
import com.ssafy.timo.domain.transfer.dto.UpdateListingPriceRequestDto;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.exception.MarketClosedException;
import com.ssafy.timo.domain.transfer.exception.MarketOpenException;
import com.ssafy.timo.domain.transfer.exception.TicketNotFoundException;
import com.ssafy.timo.domain.transfer.exception.TradeNotFoundException;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * 운영 시간 가드가 <b>어느 API 에, 어느 방향으로, 어느 순서로</b> 걸려 있는지 본다.
 *
 * <p>판정 서비스를 목으로 두고 호출 여부와 순서만 확인한다. 창의 경계 자체는
 * {@link MarketHoursServiceTest} 가, 실제 시각을 오가며 도는 흐름은 통합 테스트가 본다.
 *
 * <ul>
 *   <li>공연 목록, 공연별 매물, 구매 — 열려 있어야 한다. 닫히면 저장소를 건드리기 전에 거절</li>
 *   <li>가격 수정 — 닫혀 있어야 한다. 열려 있으면 매물을 읽기 전에 거절</li>
 *   <li>등록, 취소 — 시간을 묻지 않는다</li>
 * </ul>
 */
@ExtendWith(MockitoExtension.class)
class MarketHoursGuardTest {

    private static final Long MEMBER_ID = 7L;
    private static final Long TICKET_ID = 11L;
    private static final Long LISTING_ID = 21L;
    private static final Long CONCERT_ID = 31L;
    private static final Long TRADE_ID = 41L;
    private static final long PRICE = 90_000L;
    private static final Clock CLOCK = Clock.fixed(
            LocalDateTime.of(2026, 9, 17, 12, 0).atZone(ZoneId.of("Asia/Seoul")).toInstant(),
            ZoneId.of("Asia/Seoul"));

    @Mock
    private ConcertRepository concertRepository;
    @Mock
    private TicketRepository ticketRepository;
    @Mock
    private TicketListingRepository ticketListingRepository;
    @Mock
    private TicketTradeRepository ticketTradeRepository;
    @Mock
    private ImageStorage imageStorage;
    @Mock
    private MarketHoursService marketHoursService;
    @Mock
    private ListingSoldNotifier listingSoldNotifier;
    @Mock
    private TicketNftClient ticketNftClient;
    @Mock
    private WalletService walletService;
    @Mock
    private BlockchainProperties blockchainProperties;
    @Mock
    private TicketTransferService ticketTransferService;

    private ListingService listingService;
    private PurchaseService purchaseService;
    private MarketQueryService marketQueryService;

    @BeforeEach
    void setUp() {
        listingService = new ListingService(ticketRepository, ticketListingRepository, new TicketOwnershipService(ticketRepository),
                imageStorage, marketHoursService, ticketNftClient, walletService, blockchainProperties, CLOCK);
        purchaseService = new PurchaseService(ticketListingRepository, ticketTradeRepository, ticketRepository,
                marketHoursService, listingSoldNotifier, ticketTransferService, blockchainProperties, CLOCK, new TicketOwnershipWriter(ticketRepository));
        marketQueryService = new MarketQueryService(concertRepository, ticketListingRepository,
                ticketTradeRepository, imageStorage, marketHoursService, CLOCK);
    }

    @Test
    @DisplayName("공연 목록은 닫혀 있으면 쿼리를 날리기 전에 거절된다")
    void concertsAreRejectedWhileClosed() {
        closeMarket();

        assertThatThrownBy(() -> marketQueryService.findConcerts(new MarketListRequestDto(0, 20)))
                .isInstanceOf(MarketClosedException.class);
        verifyNoInteractions(ticketListingRepository);
    }

    @Test
    @DisplayName("공연별 매물은 닫혀 있으면 공연 존재 확인보다 먼저 거절된다")
    void listingsAreRejectedWhileClosed() {
        closeMarket();

        assertThatThrownBy(() -> marketQueryService.findListings(CONCERT_ID, new MarketListRequestDto(0, 20), MEMBER_ID))
                .isInstanceOf(MarketClosedException.class);
        verifyNoInteractions(concertRepository, ticketListingRepository);
    }

    @Test
    @DisplayName("구매는 닫혀 있으면 조건부 UPDATE 로 자리를 잡기 전에 거절된다")
    void purchaseIsRejectedBeforeClaimingListing() {
        closeMarket();

        assertThatThrownBy(() -> purchaseService.purchase(LISTING_ID, new PurchaseRequestDto(PRICE), MEMBER_ID))
                .isInstanceOf(MarketClosedException.class);
        // 먼저 SOLD 로 바꾸고 나서 거절하면, 롤백되기까지 그 매물이 남에게 잠깐 사라진다.
        verifyNoInteractions(ticketListingRepository, ticketTradeRepository, ticketRepository, listingSoldNotifier);
    }

    @Test
    @DisplayName("가격 수정은 열려 있으면 매물을 읽기도 전에 거절된다")
    void updatePriceIsRejectedWhileOpen() {
        willThrow(new MarketOpenException(LocalDateTime.of(2026, 9, 17, 23, 59, 59)))
                .given(marketHoursService).requireClosed();

        assertThatThrownBy(() -> listingService.updatePrice(LISTING_ID, new UpdateListingPriceRequestDto(PRICE), MEMBER_ID))
                .isInstanceOf(MarketOpenException.class);
        verifyNoInteractions(ticketListingRepository);
    }

    @Test
    @DisplayName("등록은 운영 시간을 묻지 않는다 - 닫힌 시간에 올린 매물이 08:00 에 드러난다")
    void registerIgnoresMarketHours() {
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.empty());

        // 티켓 조회까지 내려가 404 가 나면 시간 가드는 없는 것이다.
        assertThatThrownBy(() -> listingService.register(new CreateListingRequestDto(TICKET_ID, PRICE), MEMBER_ID))
                .isInstanceOf(TicketNotFoundException.class);
        verify(marketHoursService, never()).requireOpen();
        verify(marketHoursService, never()).requireClosed();
    }

    @Test
    @DisplayName("취소는 운영 시간을 묻지 않는다 - 내 매물을 내리는 것은 언제든 가능해야 한다")
    void cancelIgnoresMarketHours() {
        TicketListing listing = mock(TicketListing.class);
        Ticket ticket = mock(Ticket.class);
        given(listing.isSeller(MEMBER_ID)).willReturn(true);
        given(listing.getTicketId()).willReturn(TICKET_ID);
        given(ticketListingRepository.findById(LISTING_ID)).willReturn(Optional.of(listing));
        given(ticketListingRepository.markCanceledIfListed(anyLong(), any(LocalDateTime.class))).willReturn(1);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ticket));

        listingService.cancel(LISTING_ID, MEMBER_ID);

        verify(marketHoursService, never()).requireOpen();
        verify(marketHoursService, never()).requireClosed();
    }

    @Test
    @DisplayName("거래 상세는 운영 시간을 묻지 않는다 - 자기 거래를 보는 경로다")
    void findTradeIgnoresMarketHours() {
        given(ticketTradeRepository.findDetailById(TRADE_ID)).willReturn(Optional.empty());

        // 거래 조회까지 내려가 404 가 나면 시간 가드는 없는 것이다.
        assertThatThrownBy(() -> marketQueryService.findTrade(TRADE_ID, MEMBER_ID))
                .isInstanceOf(TradeNotFoundException.class);
        verify(marketHoursService, never()).requireOpen();
        verify(marketHoursService, never()).requireClosed();
    }

    private void closeMarket() {
        willThrow(new MarketClosedException(LocalDateTime.of(2026, 9, 17, 20, 0)))
                .given(marketHoursService).requireOpen();
    }
}
