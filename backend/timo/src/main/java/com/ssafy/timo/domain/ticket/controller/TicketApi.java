package com.ssafy.timo.domain.ticket.controller;

import com.ssafy.timo.domain.ticket.dto.MyTicketListRequestDto;
import com.ssafy.timo.domain.ticket.dto.MyTicketSummaryResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;

/**
 * 티켓 API 규약.
 *
 * <p>요청자는 {@link CurrentMember} 로만 받는다. 남의 보유 목록을 보는 통로를 만들지 않으려고
 * 경로나 쿼리로 회원 식별자를 받지 않는다({@code MarketApi} 와 같다).
 *
 * <p>매핑과 검증 애노테이션은 여기에만 둔다. 이유는 {@code VenueApi} 참고.
 */
public interface TicketApi {

    /**
     * 내가 지금 가진 티켓 목록. 최근 거래 순이다.
     *
     * <p>예매 목록({@code GET /api/v1/reservations})과 다른 목록이다. 그쪽은 "내가 예매한 이력" 이라
     * 양도해도 남지만, 이쪽은 "지금 내 것" 이라 판 티켓이 빠지고 산 티켓이 들어온다. 둘을 겸하던
     * 시절 양도 후 소유가 양쪽에서 뒤집혀 보이던 것이 이 API 의 존재 이유다.
     *
     * <p>{@code reservationId} 를 그대로 믿지 않는다 — 양도받은 티켓이면 판 사람의 예매라,
     * 취소와 상세는 {@code acquiredBy} 가 {@code BOOKING} 일 때만 걸 수 있다. 양도 등록이 받는 값은
     * {@code ticketId} 이고, 등록 중이면 {@code listed} 가 {@code true} 다.
     */
    @GetMapping("/me")
    ResponseEntity<PagedModel<MyTicketSummaryResponseDto>> findMyTickets(
            @Valid @ModelAttribute MyTicketListRequestDto request,
            @CurrentMember Long memberId);
}
