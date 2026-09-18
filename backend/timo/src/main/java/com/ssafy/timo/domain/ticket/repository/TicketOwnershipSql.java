package com.ssafy.timo.domain.ticket.repository;

/**
 * "이 회원이 지금 가진 티켓" 을 고르는 네이티브 SQL 조각. <b>이 규칙이 사는 유일한 곳이다.</b>
 *
 * <p>규칙은 두 갈래다 - 내가 예매했고 거래된 적 없는 티켓, 그리고 마지막 거래
 * ({@code MAX(trade_id)})에서 내가 산 티켓. 재양도({@code A->B->C})가 있어 마지막 거래만 본다.
 *
 * <p><b>왜 상수로 빼는가.</b> 이 두 갈래가 네 군데 쿼리에 글자 그대로 복사돼 있었다
 * ({@code TicketRepository.findMyTickets} 의 본문과 countQuery, {@code GoodsRepository} 의
 * 소유 판정과 소장품 목록). 네이티브라 기동 시점에 검증되지 않으므로, 한쪽만 고쳐도 아무 데서도
 * 티가 나지 않고 "내 티켓 목록에는 있는데 굿즈는 못 만드는 티켓" 같은 형태로만 드러난다.
 *
 * <p>두 갈래는 서로 배타적이라({@code ticket_trade} 행이 있거나 없거나) {@code union} 이 행을
 * 합칠 일이 없다. 그래서 필요 없는 컬럼이 끼어도 결과 집합이 달라지지 않고, 개수만 세는 쪽도
 * 이 조각을 그대로 쓸 수 있다.
 *
 * <p>두 갈래 모두 인덱스에서 출발한다({@code ix_rsv_member}, {@code idx_trade_buyer}).
 * {@code where coalesce(마지막구매자, 예매자) = :memberId} 로 쓰면 유도값이라 인덱스를 못 탄다.
 *
 * <p>쓰는 쪽은 {@code :memberId} 를 파라미터로 받아야 하고, 결과를 감싸 별칭을 붙여 쓴다 -
 * {@code from (} + {@link #CURRENT_OWNER} + {@code ) owned}. 특정 티켓 하나만 보고 싶으면
 * 조각 안이 아니라 바깥에서 {@code owned.ticket_id = :ticketId} 로 거른다.
 */
public final class TicketOwnershipSql {

    /**
     * 컬럼은 {@code ticket_id}, {@code acquired_by}({@code BOOKING}/{@code TRANSFER}),
     * {@code acquired_at} 셋이다. 안 쓰는 쪽은 무시하면 된다.
     */
    public static final String CURRENT_OWNER = """
            select t1.ticket_id   as ticket_id,
                   'BOOKING'      as acquired_by,
                   r1.created_at  as acquired_at
              from ticket t1
              join reservation r1 on r1.reservation_id = t1.reservation_id
             where r1.member_id = :memberId
               and not exists (select 1 from ticket_trade tt
                                where tt.ticket_id = t1.ticket_id)
            union
            select tt2.ticket_id  as ticket_id,
                   'TRANSFER'     as acquired_by,
                   tt2.traded_at  as acquired_at
              from ticket_trade tt2
             where tt2.buyer_member_id = :memberId
               and tt2.trade_id = (select max(x.trade_id) from ticket_trade x
                                    where x.ticket_id = tt2.ticket_id)
            """;

    private TicketOwnershipSql() {
    }
}
