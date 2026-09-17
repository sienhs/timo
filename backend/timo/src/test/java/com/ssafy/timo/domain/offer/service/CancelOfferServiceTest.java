package com.ssafy.timo.domain.offer.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.offer.entity.CancelOffer;
import com.ssafy.timo.domain.offer.repository.CancelOfferRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.Random;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 추첨 규칙을 본다. 난수는 시드를 고정해 "누가 뽑히는지" 까지 재현한다.
 *
 * <p>제외 규칙이 핵심이다 — 취소한 본인, 티켓 보유자, 이미 기회를 가진 사람은 후보에서 빠져야 하고,
 * 후보가 없으면 기회를 만들지도 이벤트를 내지도 않아야 한다.
 */
@ExtendWith(MockitoExtension.class)
class CancelOfferServiceTest {

    private static final Long CONCERT_ID = 4L;
    private static final Long SEAT_ID = 111L;
    private static final Long RESERVATION_ID = 31L;
    private static final Long CANCELLER = 1L;
    private static final Long HOLDER = 2L;
    private static final Long ALREADY_OFFERED = 3L;
    private static final Long CANDIDATE_A = 4L;
    private static final Long CANDIDATE_B = 5L;
    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 17, 21, 0);

    @Mock
    private CancelOfferRepository cancelOfferRepository;
    @Mock
    private ConcertWishRepository concertWishRepository;
    @Mock
    private TicketRepository ticketRepository;
    @Mock
    private ConcertRepository concertRepository;
    @Mock
    private SeatRepository seatRepository;
    @Mock
    private MemberRepository memberRepository;
    @Mock
    private ApplicationEventPublisher eventPublisher;
    @Mock
    private ImageStorage imageStorage;

    private CancelOfferService service;

    @BeforeEach
    void setUp() {
        service = new CancelOfferService(cancelOfferRepository, concertWishRepository, ticketRepository,
                concertRepository, seatRepository, memberRepository, eventPublisher, imageStorage,
                new Random(42), Clock.fixed(NOW.atZone(ZONE).toInstant(), ZONE));
    }

    @Test
    @DisplayName("취소한 본인, 보유자, 기회 보유자를 뺀 찜 회원 중에서 뽑고 기한은 1시간이다")
    void drawsAmongEligibleWishers() {
        given(concertWishRepository.findMemberIdsByConcertId(CONCERT_ID))
                .willReturn(List.of(CANCELLER, HOLDER, ALREADY_OFFERED, CANDIDATE_A, CANDIDATE_B));
        given(ticketRepository.findHoldingMemberIdsByConcertId(CONCERT_ID)).willReturn(List.of(HOLDER));
        given(cancelOfferRepository.findActiveMemberIdsByConcertId(CONCERT_ID, NOW)).willReturn(List.of(ALREADY_OFFERED));
        stubReferences();
        given(cancelOfferRepository.saveAndFlush(any(CancelOffer.class))).willAnswer(invocation -> {
            CancelOffer offer = invocation.getArgument(0);
            ReflectionTestUtils.setField(offer, "id", 77L);
            return offer;
        });

        Optional<CancelOffer> offer = service.offerRevokedSeat(CONCERT_ID, SEAT_ID, RESERVATION_ID, CANCELLER);

        assertThat(offer).isPresent();
        assertThat(offer.get().getExpiresAt()).isEqualTo(NOW.plusHours(1));
        assertThat(offer.get().getMember().getId()).isIn(CANDIDATE_A, CANDIDATE_B);

        ArgumentCaptor<CancelOfferGrantedEvent> event = ArgumentCaptor.forClass(CancelOfferGrantedEvent.class);
        verify(eventPublisher).publishEvent(event.capture());
        assertThat(event.getValue().offerId()).isEqualTo(77L);
        assertThat(event.getValue().memberId()).isEqualTo(offer.get().getMember().getId());
        assertThat(event.getValue().expiresAt()).isEqualTo(NOW.plusHours(1));
    }

    @Test
    @DisplayName("후보가 없으면 기회를 만들지 않고 이벤트도 내지 않는다 - 좌석은 즉시 열린다")
    void noCandidatesMeansNoOffer() {
        given(concertWishRepository.findMemberIdsByConcertId(CONCERT_ID)).willReturn(List.of(CANCELLER, HOLDER));
        given(ticketRepository.findHoldingMemberIdsByConcertId(CONCERT_ID)).willReturn(List.of(HOLDER));
        given(cancelOfferRepository.findActiveMemberIdsByConcertId(CONCERT_ID, NOW)).willReturn(List.of());

        Optional<CancelOffer> offer = service.offerRevokedSeat(CONCERT_ID, SEAT_ID, RESERVATION_ID, CANCELLER);

        assertThat(offer).isEmpty();
        verify(cancelOfferRepository, never()).saveAndFlush(any());
        verify(eventPublisher, never()).publishEvent(any());
    }

    @Test
    @DisplayName("같은 좌석의 지난 기회를 먼저 닫는다 - 유니크 제약이 그 행을 붙들고 있다")
    void expiresStaleOfferBeforeDrawing() {
        given(concertWishRepository.findMemberIdsByConcertId(CONCERT_ID)).willReturn(List.of());
        given(ticketRepository.findHoldingMemberIdsByConcertId(CONCERT_ID)).willReturn(List.of());
        given(cancelOfferRepository.findActiveMemberIdsByConcertId(CONCERT_ID, NOW)).willReturn(List.of());

        service.offerRevokedSeat(CONCERT_ID, SEAT_ID, RESERVATION_ID, CANCELLER);

        verify(cancelOfferRepository).expireStaleOfSeat(CONCERT_ID, SEAT_ID, NOW);
    }

    @Test
    @DisplayName("결제가 기회를 쓴 것인지는 조건부 UPDATE 의 영향 행으로 판정한다")
    void acceptIsJudgedByUpdate() {
        given(cancelOfferRepository.markAcceptedIfActive(CONCERT_ID, SEAT_ID, CANDIDATE_A, 99L, NOW)).willReturn(1);
        given(cancelOfferRepository.markAcceptedIfActive(CONCERT_ID, SEAT_ID, CANDIDATE_B, 99L, NOW)).willReturn(0);

        assertThat(service.acceptIfActive(CONCERT_ID, SEAT_ID, CANDIDATE_A, 99L)).isTrue();
        assertThat(service.acceptIfActive(CONCERT_ID, SEAT_ID, CANDIDATE_B, 99L)).isFalse();
    }

    private void stubReferences() {
        given(concertRepository.getReferenceById(CONCERT_ID)).willReturn(Concert.builder().title("공연").build());
        given(seatRepository.getReferenceById(SEAT_ID)).willReturn(Seat.builder().seatNo(1).seatCol(1).build());
        given(memberRepository.getReferenceById(anyLong())).willAnswer(invocation -> {
            Member member = Member.builder().phoneNumber("01000000000").name("회원").nickname("회원").build();
            ReflectionTestUtils.setField(member, "id", invocation.getArgument(0));
            return member;
        });
    }
}
