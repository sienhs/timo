package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * DB의 현재 귀속 회원을 묻는 공통 창구. memberId는 인증 컨텍스트에서 전달한다.
 * 티켓 상태·시간·주문 권한과 기존 온체인 검증은 호출 도메인이 계속 담당한다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TicketOwnershipService {
    private final TicketRepository ticketRepository;

    public Optional<Ticket> findAssignedTicket(Long memberId, Long ticketId) {
        return ticketRepository.findByIdAndOwnerMemberId(ticketId, memberId);
    }

    public boolean isAssignedTo(Long memberId, Long ticketId) {
        return ticketRepository.existsByIdAndOwnerMemberId(ticketId, memberId);
    }

    public Map<Long, List<Long>> findHolderMemberIds(Collection<Long> concertIds) {
        Map<Long, List<Long>> result = new LinkedHashMap<>();
        for (Long concertId : new LinkedHashSet<>(concertIds)) {
            result.put(concertId, ticketRepository.findHoldingMemberIdsByConcertId(concertId));
        }
        return result;
    }
}
