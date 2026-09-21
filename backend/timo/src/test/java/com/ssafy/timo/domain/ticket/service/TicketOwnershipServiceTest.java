package com.ssafy.timo.domain.ticket.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.ticket.dto.TicketAcquisition;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import java.time.LocalDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

@ExtendWith(MockitoExtension.class)
class TicketOwnershipServiceTest {
    @Mock TicketRepository repository;

    @Test
    void bookingCapturesOriginalMemberAndReservationTime() {
        Member member = Member.builder().name("owner").build();
        ReflectionTestUtils.setField(member, "id", 7L);
        Reservation reservation = Reservation.builder().member(member).build();
        LocalDateTime bookedAt = LocalDateTime.of(2026, 9, 21, 12, 0);
        ReflectionTestUtils.setField(reservation, "createdAt", bookedAt);
        Ticket ticket = Ticket.builder().reservation(reservation).build();
        assertThat(ticket.getOwnerMemberId()).isEqualTo(7L);
        assertThat(ticket.getAcquiredBy()).isEqualTo(TicketAcquisition.BOOKING);
        assertThat(ticket.getAcquiredAt()).isEqualTo(bookedAt);
        ticket.revoke();
        assertThat(ticket.getOwnerMemberId()).isEqualTo(7L);
        assertThat(ticket.getAcquiredAt()).isEqualTo(bookedAt);
    }

    @Test
    void holdersPreserveEmptyConcertsAndDeduplicateInput() {
        given(repository.findHoldingMemberIdsByConcertId(1L)).willReturn(List.of(7L, 8L));
        given(repository.findHoldingMemberIdsByConcertId(2L)).willReturn(List.of());
        var result = new TicketOwnershipService(repository).findHolderMemberIds(List.of(1L, 2L, 1L));
        assertThat(result).containsOnlyKeys(1L, 2L);
        assertThat(result.get(1L)).containsExactly(7L, 8L);
        assertThat(result.get(2L)).isEmpty();
        verify(repository).findHoldingMemberIdsByConcertId(1L);
    }

    @Test
    void emptyConcertsDoNotQuery() {
        assertThat(new TicketOwnershipService(repository).findHolderMemberIds(List.of())).isEmpty();
        verifyNoInteractions(repository);
    }
}
