package com.ssafy.timo.domain.ticket.controller;

import com.ssafy.timo.domain.ticket.dto.MyTicketListRequestDto;
import com.ssafy.timo.domain.ticket.dto.MyTicketSummaryResponseDto;
import com.ssafy.timo.domain.ticket.service.TicketQueryService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 티켓 API (v1). 매핑과 규약은 {@link TicketApi} 에 있고 여기서는 버전 경로만 정한다.
 *
 * <p>인증을 요구한다. {@code SecurityConfig} 의 {@code anyRequest().authenticated()} 가 받으므로
 * 경로를 따로 등록하지 않는다 — permitAll 목록에 없으면 잠긴다.
 */
@RestController
@RequestMapping("/api/v1/tickets")
@RequiredArgsConstructor
public class TicketController implements TicketApi {

    private final TicketQueryService ticketQueryService;

    @Override
    public ResponseEntity<PagedModel<MyTicketSummaryResponseDto>> findMyTickets(
            MyTicketListRequestDto request, Long memberId) {
        return ResponseEntity.ok(ticketQueryService.findMyTickets(memberId, request));
    }
}
