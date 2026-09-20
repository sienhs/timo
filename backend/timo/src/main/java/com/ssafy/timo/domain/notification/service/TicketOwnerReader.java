package com.ssafy.timo.domain.notification.service;

import java.util.Collection;
import java.util.List;
import java.util.Map;

/**
 * 공연의 "현재 티켓 보유자"를 알림이 묻는 창구. 알림이 소유하는 인터페이스이고, 구현은 티켓 쪽이 준다.
 *
 * <p>보유자를 정하는 규칙은 티켓 도메인의 것이다. 알림이 그 규칙을 직접 알면 규칙이 바뀔 때 알림도
 * 함께 고쳐야 하므로, 알림은 이 질문만 하고 답을 받는다. 입장 가능과 공연 일정 알림이 이 창구를 쓴다.
 *
 * <p><b>계약. 호출부가 알아야 하는 것들이다.</b>
 * <ul>
 *   <li><b>기준은 DB 다.</b> 마지막 거래의 구매자이고, 거래가 없으면 예매자다. 온체인 소유자와는
 *       다를 수 있다. 양도의 온체인 연동이 아직 없어 DB 가 유일한 기준이다.</li>
 *   <li><b>취소된 예매는 걸러진다.</b> 단, 한 번도 거래되지 않은 티켓만 그렇다. 거래된 티켓은 마지막
 *       구매자를 그대로 돌려주며 원 주문의 상태를 다시 보지 않는다.</li>
 *   <li><b>티켓 상태는 보지 않는다.</b> 발행 대기({@code PENDING_MINT})와 발행 실패({@code MINT_FAILED})는
 *       걸러지지 않는다. 입장 완료·회수·환불 상태도 조건에 없다. 티켓 상태가 중요한 알림이면 호출부가
 *       따로 걸러야 한다.</li>
 *   <li><b>요청한 공연은 모두 키로 돌아온다.</b> 보유자가 없는 공연도 빈 목록으로 들어 있다.
 *       같은 공연 id 를 여러 번 줘도 한 번만 묻는다.</li>
 *   <li><b>한 공연 안에서 회원은 중복되지 않는다.</b> 목록 순서는 보장하지 않는다.</li>
 * </ul>
 */
public interface TicketOwnerReader {

    /**
     * 각 공연의 현재 보유자 회원 id.
     *
     * @param concertIds 보유자를 알고 싶은 공연들. 비어 있으면 빈 맵이다
     * @return 공연 id 별 보유자 회원 id. 모든 요청 공연이 키로 들어 있다
     */
    Map<Long, List<Long>> findHolderMemberIds(Collection<Long> concertIds);
}
