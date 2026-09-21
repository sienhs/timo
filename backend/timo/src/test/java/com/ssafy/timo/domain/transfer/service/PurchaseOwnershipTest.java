package com.ssafy.timo.domain.transfer.service;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.notification.service.ListingSoldNotifier;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.ticket.service.TicketOwnershipWriter;
import com.ssafy.timo.domain.transfer.dto.PurchaseRequestDto;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.exception.ListingAlreadyClosedException;
import com.ssafy.timo.domain.transfer.exception.TransferFailedException;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;
import java.math.BigInteger;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

/** 체인 호출은 유지하고, 성공 뒤에만 DB 소유권을 확정하는 호출 경계를 검증한다. */
@ExtendWith(MockitoExtension.class)
class PurchaseOwnershipTest {
    private static final Long LISTING = 10L, TICKET = 20L, SELLER = 30L, BUYER = 40L;
    private static final long PRICE = 90_000L;
    private static final Clock CLOCK = Clock.fixed(Instant.parse("2026-09-21T09:00:00Z"), ZoneOffset.UTC);
    private static final LocalDateTime NOW = LocalDateTime.now(CLOCK);

    @Mock TicketListingRepository listings;
    @Mock TicketTradeRepository trades;
    @Mock TicketRepository tickets;
    @Mock MarketHoursService hours;
    @Mock ListingSoldNotifier notifier;
    @Mock TicketTransferService chain;
    @Mock BlockchainProperties properties;

    private PurchaseService service;

    @BeforeEach
    void setUp() {
        Member member = Member.builder().name("seller").build();
        ReflectionTestUtils.setField(member, "id", SELLER);
        Concert concert = Concert.builder().title("concert")
                .venue(com.ssafy.timo.domain.venue.entity.Venue.builder().name("venue").build()).build();
        Section section = Section.builder().name("A").build();
        Ticket ticket = Ticket.builder().reservation(Reservation.builder().member(member).concert(concert).build()).build();
        ReflectionTestUtils.setField(ticket, "id", TICKET);
        ticket.markMinted(BigInteger.ONE, "0xmint");
        ticket.markListed();
        TicketListing listing = TicketListing.open(TICKET, SELLER, concert, section, 1, 1, PRICE, PRICE, NOW.minusDays(1));
        ReflectionTestUtils.setField(listing, "id", LISTING);
        given(listings.findDetailById(LISTING)).willReturn(Optional.of(listing));
        given(tickets.findById(TICKET)).willReturn(Optional.of(ticket));
        given(hours.visibleBefore()).willReturn(NOW.toLocalDate().atStartOfDay());
        service = new PurchaseService(listings, trades, tickets, hours, notifier, chain, properties, CLOCK,
                new TicketOwnershipWriter(tickets));
    }

    @Test
    void chainFailureDoesNotWriteOwnershipOrTrade() {
        given(properties.hasRealAdminPrivateKey()).willReturn(true);
        given(chain.transfer(LISTING, TICKET, SELLER, BUYER, PRICE)).willThrow(new ContractCallException("failure"));
        assertThatThrownBy(() -> service.purchase(LISTING, new PurchaseRequestDto(PRICE), BUYER))
                .isInstanceOf(TransferFailedException.class);
        verify(listings, never()).markSoldIfListed(any(), any());
        verify(tickets, never()).transferOwnershipIfListed(any(), any(), any(), any());
        verifyNoInteractions(trades, notifier);
    }

    @Test
    void successfulChainCallPrecedesDatabaseOwnershipAndTrade() {
        given(properties.hasRealAdminPrivateKey()).willReturn(true);
        given(listings.markSoldIfListed(LISTING, NOW)).willReturn(1);
        given(tickets.transferOwnershipIfListed(TICKET, SELLER, BUYER, NOW)).willReturn(1);
        given(trades.save(any(TicketTrade.class))).willAnswer(invocation -> invocation.getArgument(0));
        service.purchase(LISTING, new PurchaseRequestDto(PRICE), BUYER);
        var order = inOrder(chain, listings, tickets, trades);
        order.verify(chain).transfer(LISTING, TICKET, SELLER, BUYER, PRICE);
        order.verify(listings).markSoldIfListed(LISTING, NOW);
        order.verify(tickets).transferOwnershipIfListed(TICKET, SELLER, BUYER, NOW);
        order.verify(trades).save(any(TicketTrade.class));
    }

    @Test
    void ownershipConflictDoesNotRecordTradeOrNotify() {
        given(listings.markSoldIfListed(LISTING, NOW)).willReturn(1);
        given(tickets.transferOwnershipIfListed(TICKET, SELLER, BUYER, NOW)).willReturn(0);
        assertThatThrownBy(() -> service.purchase(LISTING, new PurchaseRequestDto(PRICE), BUYER))
                .isInstanceOf(ListingAlreadyClosedException.class);
        verifyNoInteractions(chain, trades, notifier);
    }

    @Test
    void closedListingDoesNotAttemptOwnershipUpdate() {
        given(listings.markSoldIfListed(LISTING, NOW)).willReturn(0);
        assertThatThrownBy(() -> service.purchase(LISTING, new PurchaseRequestDto(PRICE), BUYER))
                .isInstanceOf(ListingAlreadyClosedException.class);
        verify(tickets, never()).transferOwnershipIfListed(any(), any(), any(), any());
        verifyNoInteractions(trades, notifier);
    }
}
