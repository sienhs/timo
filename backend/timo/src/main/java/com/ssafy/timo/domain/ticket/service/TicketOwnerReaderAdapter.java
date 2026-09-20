package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.domain.notification.service.TicketOwnerReader;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;

/**
 * 알림이 묻는 "현재 티켓 보유자"에 티켓 도메인의 판정으로 답한다.
 *
 * <p>판정 규칙은 새로 만들지 않고 {@link TicketRepository#findHoldingMemberIdsByConcertId} 를 그대로
 * 부른다. 규칙이 이미 여러 벌로 흩어져 있어서 한 벌을 더 늘리지 않으려는 것이다. 이 쿼리는 공연 하나씩만
 * 받으므로 공연마다 한 번 부른다. 나중에 여러 공연을 한 번에 묻는 쿼리가 생기면 이 클래스만 바꾸면 된다.
 *
 * <p>계약은 {@link TicketOwnerReader} 에 있다.
 */
@Component
@RequiredArgsConstructor
public class TicketOwnerReaderAdapter implements TicketOwnerReader {

    private final TicketRepository ticketRepository;

    @Override
    @Transactional(readOnly = true)
    public Map<Long, List<Long>> findHolderMemberIds(Collection<Long> concertIds) {
        Map<Long, List<Long>> holders = new LinkedHashMap<>();
        // 같은 공연을 두 번 묻지 않는다. 호출부가 매물 목록에서 공연 id 를 그대로 모아 줘도 안전하다.
        for (Long concertId : new LinkedHashSet<>(concertIds)) {
            holders.put(concertId, ticketRepository.findHoldingMemberIdsByConcertId(concertId));
        }
        return holders;
    }
}
