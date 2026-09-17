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

import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.dto.CreateListingRequestDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseRequestDto;
import com.ssafy.timo.domain.transfer.dto.UpdateListingPriceRequestDto;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.exception.MarketClosedException;
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
 * 운영 시간 가드가 <b>어느 API 에, 어느 순서로</b> 걸려 있는지 본다.
 *
 * <p>통합 테스트는 test 프로파일이 종일 열려 있어 닫힌 경로를 탈 수 없다. 여기서는 판정 서비스를
 * 목으로 닫아 두고, 거절이 저장소를 건드리기 전에 일어나는지와 취소는 판정을 아예 묻지 않는지를
 * 확인한다. 창의 경계 자체는 {@link MarketHoursServiceTest} 가 본다.
 */
@ExtendWith(MockitoExtension.class)
class MarketHoursGuardTest {

    private static final Long MEMBER_ID = 7L;
    private static final Long TICKET_ID = 11L;
    private static final Long LISTING_ID = 21L;
    private static final long PRICE = 90_000L;
    private static final Clock CLOCK = Clock.fixed(
            LocalDateTime.of(2026, 9, 17, 12, 0).atZone(ZoneId.of("Asia/Seoul")).toInstant(),
            ZoneId.of("Asia/Seoul"));

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

    private ListingService listingService;
    private PurchaseService purchaseService;

    @BeforeEach
    void setUp() {
        listingService = new ListingService(ticketRepository, ticketListingRepository, ticketTradeRepository,
                imageStorage, marketHoursService, CLOCK);
        purchaseService = new PurchaseService(ticketListingRepository, ticketTradeRepository,
                marketHoursService, CLOCK);
    }

    @Test
    @DisplayName("닫혀 있으면 등록은 티켓을 읽기도 전에 거절된다")
    void registerIsRejectedBeforeReadingTicket() {
        closeMarket();

        assertThatThrownBy(() -> listingService.register(new CreateListingRequestDto(TICKET_ID, PRICE), MEMBER_ID))
                .isInstanceOf(MarketClosedException.class);
        verifyNoInteractions(ticketRepository, ticketListingRepository, ticketTradeRepository);
    }

    @Test
    @DisplayName("닫혀 있으면 가격 수정은 매물을 읽기도 전에 거절된다")
    void updatePriceIsRejectedBeforeReadingListing() {
        closeMarket();

        assertThatThrownBy(() -> listingService.updatePrice(LISTING_ID, new UpdateListingPriceRequestDto(PRICE), MEMBER_ID))
                .isInstanceOf(MarketClosedException.class);
        verifyNoInteractions(ticketListingRepository);
    }

    @Test
    @DisplayName("닫혀 있으면 구매는 조건부 UPDATE 로 자리를 잡기 전에 거절된다")
    void purchaseIsRejectedBeforeClaimingListing() {
        closeMarket();

        assertThatThrownBy(() -> purchaseService.purchase(LISTING_ID, new PurchaseRequestDto(PRICE), MEMBER_ID))
                .isInstanceOf(MarketClosedException.class);
        // 먼저 SOLD 로 바꾸고 나서 거절하면, 롤백되기까지 그 매물이 남에게 잠깐 사라진다.
        verifyNoInteractions(ticketListingRepository, ticketTradeRepository);
    }

    @Test
    @DisplayName("취소는 운영 시간을 묻지 않는다 - 내 매물을 내리는 것은 언제든 가능해야 한다")
    void cancelIgnoresMarketHours() {
        TicketListing listing = mock(TicketListing.class);
        given(listing.isSeller(MEMBER_ID)).willReturn(true);
        given(ticketListingRepository.findById(LISTING_ID)).willReturn(Optional.of(listing));
        given(ticketListingRepository.markCanceledIfListed(anyLong(), any(LocalDateTime.class))).willReturn(1);

        listingService.cancel(LISTING_ID, MEMBER_ID);

        verify(marketHoursService, never()).requireOpen();
    }

    private void closeMarket() {
        willThrow(new MarketClosedException(LocalDateTime.of(2026, 9, 17, 20, 0)))
                .given(marketHoursService).requireOpen();
    }
}
