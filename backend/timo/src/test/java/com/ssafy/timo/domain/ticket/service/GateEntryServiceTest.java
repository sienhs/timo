package com.ssafy.timo.domain.ticket.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;

import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyRequestDto;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyResponseDto;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyResponseDto.HolderInfo;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyResponseDto.SeatInfo;
import com.ssafy.timo.domain.ticket.dto.GateRejectReason;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.wallet.entity.Wallet;
import com.ssafy.timo.domain.wallet.repository.WalletRepository;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;
import com.ssafy.timo.global.config.ticket.EntryPassProperties;
import java.math.BigInteger;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 게이트 검표 판정을 검증한다.
 *
 * <p>{@link EntryPassProvider} 는 목이 아니라 실제 구현을 쓴다. 발급기가 만든 문자열을 그대로
 * 먹여야 "앱에선 되는데 게이트에서 막히는" 어긋남을 여기서 잡을 수 있다.
 *
 * <p>기본 설정은 체인이 없는 환경({@code adminPrivateKey} 빈 값)이다. 온체인 소유자 검사를 타는
 * 경우는 {@link #onChainService()} 로 따로 세운다.
 */
@ExtendWith(MockitoExtension.class)
class GateEntryServiceTest {

    private static final String SECRET = "local-dev-only-entry-pass-secret-0123456789";
    private static final Duration TTL = Duration.ofSeconds(60);
    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
    private static final Instant NOW = Instant.parse("2026-09-17T10:00:00Z");

    private static final Long TICKET_ID = 324L;
    private static final Long CONCERT_ID = 4L;
    private static final Long OTHER_CONCERT_ID = 3L;
    private static final Long MEMBER_ID = 111L;
    private static final BigInteger TOKEN_ID = BigInteger.valueOf(77);
    private static final String OWNER_ADDRESS = "0xAbC0000000000000000000000000000000000001";
    private static final String SECTION_NAME = "B구역";
    private static final int SEAT_NO = 14;
    private static final int SEAT_COL = 12;
    private static final String HOLDER_NAME = "장민석";
    private static final String HOLDER_PHONE = "01012345678";

    @Mock
    private TicketRepository ticketRepository;

    @Mock
    private WalletRepository walletRepository;

    @Mock
    private TicketNftClient ticketNftClient;

    @Mock
    private ApplicationEventPublisher eventPublisher;

    @Test
    @DisplayName("유효한 QR 이면 입장시키고 티켓을 소진한다")
    void admitsValidPass() {
        given(ticketRepository.findForGateEntry(TICKET_ID)).willReturn(Optional.of(ownedTicket()));
        given(ticketRepository.markUsedIfOwned(TICKET_ID)).willReturn(1);

        GateEntryVerifyResponseDto response = service().verify(request(issuedQr()));

        assertThat(response.admitted()).isTrue();
        assertThat(response.reasonCode()).isNull();
        assertThat(response.seat()).isEqualTo(new SeatInfo(SECTION_NAME, SEAT_NO, SEAT_COL));
        // 연락처는 서버에서 가려 내린다. 앱이 가리면 프록시·로그를 원문이 그대로 지나간다.
        assertThat(response.holder()).isEqualTo(new HolderInfo(HOLDER_NAME, "010****5678"));
        then(eventPublisher).should().publishEvent(new TicketEnteredEvent(TICKET_ID, TOKEN_ID));
    }

    @Test
    @DisplayName("우리 QR 이 아니면 티켓을 조회하지도 않는다")
    void rejectsForeignString() {
        GateEntryVerifyResponseDto response = service().verify(request("https://example.com"));

        assertThat(response.reasonCode()).isEqualTo(GateRejectReason.INVALID);
        // 아무 문자열이나 던져 티켓 조회를 유발할 수 있으면 안 된다.
        then(ticketRepository).should(never()).findForGateEntry(any());
    }

    @Test
    @DisplayName("수명이 지난 QR 은 거절한다")
    void rejectsExpiredPass() {
        String qr = issuedQr();

        GateEntryVerifyResponseDto response = serviceAt(NOW.plus(TTL).plusSeconds(1)).verify(request(qr));

        assertThat(response.reasonCode()).isEqualTo(GateRejectReason.EXPIRED);
    }

    @Test
    @DisplayName("다른 공연 티켓은 거절한다")
    void rejectsTicketOfAnotherConcert() {
        given(ticketRepository.findForGateEntry(TICKET_ID)).willReturn(Optional.of(ownedTicket()));

        GateEntryVerifyResponseDto response = service()
                .verify(new GateEntryVerifyRequestDto(issuedQr(), OTHER_CONCERT_ID));

        assertThat(response.reasonCode()).isEqualTo(GateRejectReason.WRONG_CONCERT);
    }

    @Test
    @DisplayName("이미 입장한 티켓은 거절한다")
    void rejectsAlreadyUsedTicket() {
        Ticket ticket = ownedTicket();
        ticket.markUsed();
        given(ticketRepository.findForGateEntry(TICKET_ID)).willReturn(Optional.of(ticket));

        GateEntryVerifyResponseDto response = service().verify(request(issuedQr()));

        assertThat(response.reasonCode()).isEqualTo(GateRejectReason.ALREADY_USED);
        // 운영자가 "이미 입장한 그 자리" 를 확인시켜 줄 수 있어야 한다.
        assertThat(response.seat()).isEqualTo(new SeatInfo(SECTION_NAME, SEAT_NO, SEAT_COL));
        // 들여보내지 않은 사람의 예매자 정보까지 단말에 띄울 이유는 없다.
        assertThat(response.holder()).isNull();
        then(ticketRepository).should(never()).markUsedIfOwned(any());
    }

    @Test
    @DisplayName("회수된 티켓은 거절한다")
    void rejectsRevokedTicket() {
        Ticket ticket = ownedTicket();
        ticket.revoke();
        given(ticketRepository.findForGateEntry(TICKET_ID)).willReturn(Optional.of(ticket));

        GateEntryVerifyResponseDto response = service().verify(request(issuedQr()));

        assertThat(response.reasonCode()).isEqualTo(GateRejectReason.REVOKED);
        // 좌석을 알아도 운영자가 할 일이 없는 거절이다. 노출 범위만 넓어진다.
        assertThat(response.seat()).isNull();
        assertThat(response.holder()).isNull();
    }

    @Test
    @DisplayName("발행 전 티켓은 내부 진행 상태를 알리지 않고 거절한다")
    void rejectsPendingMintTicket() {
        Ticket pending = Ticket.builder().reservation(reservation()).build();
        ReflectionTestUtils.setField(pending, "id", TICKET_ID);
        given(ticketRepository.findForGateEntry(TICKET_ID)).willReturn(Optional.of(pending));

        GateEntryVerifyResponseDto response = service().verify(request(issuedQr()));

        assertThat(response.reasonCode()).isEqualTo(GateRejectReason.INVALID);
    }

    @Test
    @DisplayName("상태 확인을 통과해도 소진에 실패하면 입장시키지 않는다")
    void rejectsWhenAnotherGateConsumedFirst() {
        Ticket consumed = ownedTicket();
        consumed.markUsed();
        // 상태 검사 때는 OWNED 였는데, 그 사이 다른 게이트가 먼저 소진한 상황이다.
        // 재조회만 findById 다 - 사유를 가를 상태 하나면 되고 좌석은 이미 떠 뒀다.
        given(ticketRepository.findForGateEntry(TICKET_ID)).willReturn(Optional.of(ownedTicket()));
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(consumed));
        given(ticketRepository.markUsedIfOwned(TICKET_ID)).willReturn(0);

        GateEntryVerifyResponseDto response = service().verify(request(issuedQr()));

        assertThat(response.admitted()).isFalse();
        assertThat(response.reasonCode()).isEqualTo(GateRejectReason.ALREADY_USED);
        // 소진 UPDATE 가 영속성 컨텍스트를 비운 뒤라, 좌석을 여기서 읽으려 했다면 터졌을 자리다.
        assertThat(response.seat()).isEqualTo(new SeatInfo(SECTION_NAME, SEAT_NO, SEAT_COL));
        then(eventPublisher).should(never()).publishEvent(any(TicketEnteredEvent.class));
    }

    @Test
    @DisplayName("서명은 유효한데 티켓이 없으면 거절한다")
    void rejectsSignedPassWithoutTicket() {
        given(ticketRepository.findForGateEntry(TICKET_ID)).willReturn(Optional.empty());

        GateEntryVerifyResponseDto response = service().verify(request(issuedQr()));

        assertThat(response.reasonCode()).isEqualTo(GateRejectReason.INVALID);
    }

    @Test
    @DisplayName("온체인 소유자가 다르면 거절하고 티켓을 태우지 않는다")
    void rejectsWhenOnChainOwnerDiffers() {
        given(ticketRepository.findForGateEntry(TICKET_ID)).willReturn(Optional.of(ownedTicket()));
        given(walletRepository.findById(MEMBER_ID)).willReturn(Optional.of(wallet()));
        given(ticketNftClient.ownerOf(TOKEN_ID)).willReturn("0xdEaD000000000000000000000000000000000000");

        GateEntryVerifyResponseDto response = onChainService().verify(request(issuedQr()));

        assertThat(response.reasonCode()).isEqualTo(GateRejectReason.SIGNATURE_MISMATCH);
        // 소유자 검사를 소진보다 먼저 하는 이유다. 반대였다면 정당한 소유자의 표가 여기서 탔다.
        then(ticketRepository).should(never()).markUsedIfOwned(any());
    }

    @Test
    @DisplayName("온체인 소유자가 같으면 입장시킨다")
    void admitsWhenOnChainOwnerMatches() {
        given(ticketRepository.findForGateEntry(TICKET_ID)).willReturn(Optional.of(ownedTicket()));
        given(walletRepository.findById(MEMBER_ID)).willReturn(Optional.of(wallet()));
        given(ticketRepository.markUsedIfOwned(TICKET_ID)).willReturn(1);
        // 체인은 EIP-55 체크섬 대소문자로 돌려주므로 대소문자를 구분해 비교하면 안 된다.
        given(ticketNftClient.ownerOf(TOKEN_ID)).willReturn(OWNER_ADDRESS.toLowerCase());

        GateEntryVerifyResponseDto response = onChainService().verify(request(issuedQr()));

        assertThat(response.admitted()).isTrue();
    }

    private GateEntryVerifyRequestDto request(String qr) {
        return new GateEntryVerifyRequestDto(qr, CONCERT_ID);
    }

    /** 발급기가 실제로 만든 QR. 서비스와 같은 시크릿·시계를 쓴다. */
    private String issuedQr() {
        return providerAt(NOW).issue(TICKET_ID).value();
    }

    /** 체인이 없는 환경(로컬·테스트). 온체인 소유자 검사를 건너뛴다. */
    private GateEntryService service() {
        return serviceAt(NOW);
    }

    private GateEntryService serviceAt(Instant instant) {
        return new GateEntryService(providerAt(instant), ticketRepository, walletRepository, ticketNftClient,
                new BlockchainProperties("http://localhost:8545", ""), eventPublisher);
    }

    /** 체인이 준비된 환경. 온체인 소유자 검사를 탄다. */
    private GateEntryService onChainService() {
        return new GateEntryService(providerAt(NOW), ticketRepository, walletRepository, ticketNftClient,
                new BlockchainProperties("http://localhost:8545", "0x" + "1".repeat(64)), eventPublisher);
    }

    private static EntryPassProvider providerAt(Instant instant) {
        return new EntryPassProvider(new EntryPassProperties(SECRET, TTL), Clock.fixed(instant, ZONE));
    }

    private static Ticket ownedTicket() {
        Ticket ticket = Ticket.builder().reservation(reservation()).build();
        ticket.markMinted(TOKEN_ID, "0x" + "1".repeat(64));
        ReflectionTestUtils.setField(ticket, "id", TICKET_ID);
        return ticket;
    }

    private static Reservation reservation() {
        Member member = Member.builder()
                .phoneNumber(HOLDER_PHONE).name(HOLDER_NAME).nickname("민석").build();
        ReflectionTestUtils.setField(member, "id", MEMBER_ID);

        Concert concert = Concert.builder().title("입장 테스트 공연").build();
        ReflectionTestUtils.setField(concert, "id", CONCERT_ID);

        return Reservation.builder().concert(concert).member(member).seat(seat()).build();
    }

    /** 좌석은 응답에 실리므로 null 로 둘 수 없다. 구역까지 세워야 구역명이 나온다. */
    private static Seat seat() {
        Venue venue = Venue.builder().name("테스트 공연장").address("서울").totalSeatCount(100).build();
        Section section = Section.builder()
                .name(SECTION_NAME).price(150_000).rowCount(20).seatPerRow(20).venue(venue).build();
        return Seat.builder().seatNo(SEAT_NO).seatCol(SEAT_COL).section(section).build();
    }

    private static Wallet wallet() {
        return Wallet.builder().address(OWNER_ADDRESS).encryptedKeystoreJson("{}").wrappedDek("x").build();
    }
}
