package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.domain.ticket.dto.MyTicketListRequestDto;
import com.ssafy.timo.domain.ticket.dto.MyTicketSummaryResponseDto;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 내 티켓 조회.
 *
 * <p>얇은 이유는 소유자 판정이 전부 쿼리 안에 있기 때문이다({@code TicketRepository.findMyTickets}).
 * 판정을 쿼리에 둔 것은 인덱스 때문이다 — 애플리케이션에서 예매와 체결을 따로 읽어 합치면 티켓마다
 * 추가 조회가 나가고, 유도한 소유자로 거르면 인덱스를 못 탄다.
 */
@Service
@RequiredArgsConstructor
public class TicketQueryService {

    private final TicketRepository ticketRepository;
    private final ImageStorage imageStorage;

    @Transactional(readOnly = true)
    public PagedModel<MyTicketSummaryResponseDto> findMyTickets(Long memberId, MyTicketListRequestDto request) {
        return new PagedModel<>(ticketRepository
                .findMyTickets(memberId, request.toPageable())
                .map(row -> MyTicketSummaryResponseDto.from(row, imageStorage)));
    }
}
