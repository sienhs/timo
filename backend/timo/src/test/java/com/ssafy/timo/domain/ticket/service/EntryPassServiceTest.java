package com.ssafy.timo.domain.ticket.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.BDDMockito.given;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.ticket.dto.EntryPassResponseDto;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.exception.EntryWindowClosedException;
import com.ssafy.timo.domain.ticket.exception.EntryWindowNotOpenException;
import com.ssafy.timo.domain.ticket.exception.TicketNotFoundException;
import com.ssafy.timo.domain.ticket.exception.TicketStatusNotIssuableException;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.global.config.ticket.EntryPassProperties;
import java.math.BigInteger;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 입장 QR 발급 조건을 검증한다.
 *
 * <p>{@link EntryPassProvider} 는 목이 아니라 실제 구현을 쓴다. 발급된 문자열이 같은 코덱으로 다시
 * 풀리는지까지 봐야 "발급은 되는데 게이트에서 막히는" 상태를 여기서 잡을 수 있다.
 */
@ExtendWith(MockitoExtension.class)
class EntryPassServiceTest {

    private static final String SECRET = "local-dev-only-entry-pass-secret-0123456789";
    private static final Duration TTL = Duration.ofSeconds(60);
    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

    private static final Long TICKET_ID = 324L;
    private static final Long MEMBER_ID = 7L;
    private static final Long OTHER_MEMBER_ID = 8L;

    /** 공연 시작 19:00, 지금은 18:30 - 입장 창(17:00~다음날 01:00) 한가운데다. */
    private static final LocalDateTime CONCERT_START = LocalDateTime.of(2026, 9, 17, 19, 0);
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 17, 18, 30);

    @Mock
    private TicketRepository ticketRepository;

    @Test
    @DisplayName("입장 시간대의 내 티켓이면 QR 과 남은 수명을 내려준다")
    void issuesPassForOwnedTicketWithinWindow() {
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ownedTicket(CONCERT_START)));

        EntryPassResponseDto response = serviceAt(NOW).issue(MEMBER_ID, TICKET_ID);

        assertThat(response.expiresInSeconds()).isEqualTo(TTL.toSeconds());
        // 내려준 문자열이 같은 코덱으로 다시 풀려야 게이트가 읽을 수 있다.
        assertThat(providerAt(NOW).verify(response.token()).ticketId()).isEqualTo(TICKET_ID);
    }

    @Test
    @DisplayName("없는 티켓이면 404 다")
    void rejectsMissingTicket() {
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.empty());

        assertThatThrownBy(() -> serviceAt(NOW).issue(MEMBER_ID, TICKET_ID))
                .isInstanceOf(TicketNotFoundException.class);
    }

    @Test
    @DisplayName("남의 티켓은 권한 없음이 아니라 없음으로 답한다")
    void hidesOtherMembersTicket() {
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ownedTicket(CONCERT_START)));

        // 403 이면 "그 번호의 티켓은 있다" 를 알려주는 셈이라, 번호를 훑어 예매 현황을 세어 볼 수 있다.
        assertThatThrownBy(() -> serviceAt(NOW).issue(OTHER_MEMBER_ID, TICKET_ID))
                .isInstanceOf(TicketNotFoundException.class);
    }

    @Test
    @DisplayName("회수된 티켓은 발급하지 않는다")
    void rejectsRevokedTicket() {
        Ticket ticket = ownedTicket(CONCERT_START);
        ticket.revoke();
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ticket));

        assertThatThrownBy(() -> serviceAt(NOW).issue(MEMBER_ID, TICKET_ID))
                .isInstanceOf(TicketStatusNotIssuableException.class);
    }

    @Test
    @DisplayName("아직 발행 전인 티켓은 발급하지 않는다")
    void rejectsPendingMintTicket() {
        Ticket ticket = Ticket.builder().reservation(reservation(CONCERT_START)).build();
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ticket));

        assertThatThrownBy(() -> serviceAt(NOW).issue(MEMBER_ID, TICKET_ID))
                .isInstanceOf(TicketStatusNotIssuableException.class);
    }

    @Test
    @DisplayName("입장 시작 전에는 발급하지 않는다")
    void rejectsBeforeEntryWindow() {
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ownedTicket(CONCERT_START)));

        LocalDateTime tooEarly = CONCERT_START.minus(EntryPassService.ENTRY_OPENS_BEFORE_START).minusMinutes(1);

        assertThatThrownBy(() -> serviceAt(tooEarly).issue(MEMBER_ID, TICKET_ID))
                .isInstanceOf(EntryWindowNotOpenException.class);
    }

    @Test
    @DisplayName("입장 시작 정각부터는 발급된다")
    void issuesAtWindowOpen() {
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ownedTicket(CONCERT_START)));

        LocalDateTime windowOpen = CONCERT_START.minus(EntryPassService.ENTRY_OPENS_BEFORE_START);

        assertThat(serviceAt(windowOpen).issue(MEMBER_ID, TICKET_ID).token()).isNotBlank();
    }

    @Test
    @DisplayName("입장 마감이 지나면 발급하지 않는다")
    void rejectsAfterEntryWindow() {
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ownedTicket(CONCERT_START)));

        LocalDateTime tooLate = CONCERT_START.plus(EntryPassService.ENTRY_CLOSES_AFTER_START).plusMinutes(1);

        assertThatThrownBy(() -> serviceAt(tooLate).issue(MEMBER_ID, TICKET_ID))
                .isInstanceOf(EntryWindowClosedException.class);
    }

    @Test
    @DisplayName("일정이 잡히지 않은 공연이면 시간 검사를 건너뛴다")
    void skipsWindowWhenConcertHasNoStartDate() {
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ownedTicket(null)));

        assertThat(serviceAt(NOW).issue(MEMBER_ID, TICKET_ID).token()).isNotBlank();
    }

    private EntryPassService serviceAt(LocalDateTime now) {
        Clock clock = Clock.fixed(now.atZone(ZONE).toInstant(), ZONE);
        return new EntryPassService(ticketRepository, new EntryPassProvider(properties(), clock), clock);
    }

    private static EntryPassProvider providerAt(LocalDateTime now) {
        return new EntryPassProvider(properties(), Clock.fixed(now.atZone(ZONE).toInstant(), ZONE));
    }

    private static EntryPassProperties properties() {
        return new EntryPassProperties(SECRET, TTL);
    }

    /** 발행까지 끝난({@code OWNED}) 티켓. {@code startDate} 가 {@code null} 이면 일정 미정 공연이다. */
    private static Ticket ownedTicket(LocalDateTime startDate) {
        Ticket ticket = Ticket.builder().reservation(reservation(startDate)).build();
        ticket.markMinted(BigInteger.valueOf(1), "0x" + "1".repeat(64));
        return ticket;
    }

    private static Reservation reservation(LocalDateTime startDate) {
        Member member = Member.builder().phoneNumber("01012345678").name("장민석").nickname("민석").build();
        ReflectionTestUtils.setField(member, "id", MEMBER_ID);

        Concert concert = Concert.builder().title("입장 테스트 공연").startDate(startDate).build();

        return Reservation.builder().concert(concert).member(member).seat(null).build();
    }
}
