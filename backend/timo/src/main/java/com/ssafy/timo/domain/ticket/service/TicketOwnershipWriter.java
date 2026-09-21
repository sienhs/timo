package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** 기존 양도 성공 처리의 DB 트랜잭션에 참여한다. 온체인 처리를 실행하거나 대체하지 않는다. */
@Service
@RequiredArgsConstructor
public class TicketOwnershipWriter {
    private final TicketRepository ticketRepository;

    /** sellerId는 매물에서, buyerId는 인증 컨텍스트에서 가져온 값이어야 한다. */
    @Transactional(propagation = Propagation.MANDATORY)
    public boolean transferIfListed(Long ticketId, Long sellerId, Long buyerId, LocalDateTime acquiredAt) {
        return ticketRepository.transferOwnershipIfListed(ticketId, sellerId, buyerId, acquiredAt) == 1;
    }
}
