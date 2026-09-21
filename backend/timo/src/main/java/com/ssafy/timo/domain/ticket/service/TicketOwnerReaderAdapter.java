package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.domain.notification.service.TicketOwnerReader;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * 알림이 묻는 "현재 티켓 보유자"에 티켓 도메인의 판정으로 답한다.
 *
 * <p>판정 규칙은 새로 만들지 않고 {@link TicketOwnershipService#findHolderMemberIds} 를 통해 조회한다. 알림은 티켓 소유권의 저장·판정 방법을 직접 알지 않는다.
 *
 * <p>계약은 {@link TicketOwnerReader} 에 있다.
 */
@Component
@RequiredArgsConstructor
public class TicketOwnerReaderAdapter implements TicketOwnerReader {

    private final TicketOwnershipService ticketOwnershipService;

    @Override
    @Transactional(readOnly = true)
    public Map<Long, List<Long>> findHolderMemberIds(Collection<Long> concertIds) {
        return ticketOwnershipService.findHolderMemberIds(concertIds);
    }
}
