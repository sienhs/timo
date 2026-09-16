package com.ssafy.timo.domain.ticket.repository;

import com.ssafy.timo.domain.ticket.entity.Ticket;
import java.math.BigInteger;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface TicketRepository extends JpaRepository<Ticket, Long> {

    Optional<Ticket> findByTokenId(BigInteger tokenId);

    Optional<Ticket> findByReservationId(Long reservationId);
}
