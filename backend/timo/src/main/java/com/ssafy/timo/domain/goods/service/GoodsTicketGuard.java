package com.ssafy.timo.domain.goods.service;

import com.ssafy.timo.domain.goods.exception.GoodsTicketNotOwnedException;
import com.ssafy.timo.domain.goods.exception.GoodsTicketNotUsedException;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

/**
 * "이 회원이 이 티켓으로 굿즈를 만들 수 있는가" 판정. 이미지 업로드와 굿즈 생성이 공유한다.
 *
 * <p>귀속 판정은 {@code ticket.owner_member_id} 를 그대로 따른다 - 양도되면 구매자가 만들고 원
 * 예매자는 못 만든다.
 *
 * <p>같은 규칙을 두 곳에 옮겨 적지 않으려고 뽑았다. 업로드는 저장소에 쓰기 전에(거절된 요청이
 * 객체를 남기지 않도록), 생성은 저장하기 전에 부른다. 한쪽만 고쳐 규칙이 갈리면 "올릴 때는 됐는데
 * 만들 때는 안 되는" 상태가 되고, 그때 이미 올라간 이미지는 청소 배치가 떠안는다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GoodsTicketGuard {

    private final TicketRepository ticketRepository;

    /**
     * 지금 내 티켓이고 입장까지 마쳤으면 그 티켓을, 아니면 예외를 던진다.
     *
     * @throws GoodsTicketNotOwnedException 없는 티켓이거나 지금 내 티켓이 아니면 (404, 둘을 구분하지 않는다)
     * @throws GoodsTicketNotUsedException  내 티켓이지만 입장 완료({@code USED})가 아니면 (409)
     */
    public Ticket requireUsedTicket(Long memberId, Long ticketId) {
        // 없는 티켓과 남의 티켓을 한 번에 거른다. 둘을 구분하지 않는 이유는 GoodsErrorCode 주석 참고.
        Ticket ticket = ticketRepository.findByIdAndOwnerMemberId(ticketId, memberId)
                .orElseThrow(() -> new GoodsTicketNotOwnedException(ticketId));

        if (ticket.getStatus() != TicketStatus.USED) {
            // 어떤 상태였는지는 사용자에게 알릴 이유가 없는 내부 값이라 로그로만 남긴다.
            log.debug("굿즈 작업 불가 - 티켓 상태 (ticketId={}, status={})", ticketId, ticket.getStatus());
            throw new GoodsTicketNotUsedException();
        }

        return ticket;
    }
}
