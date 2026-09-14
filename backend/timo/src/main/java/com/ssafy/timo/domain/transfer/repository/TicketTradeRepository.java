package com.ssafy.timo.domain.transfer.repository;

import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface TicketTradeRepository extends JpaRepository<TicketTrade, Long> {

    /**
     * 이 매물의 체결 건.
     *
     * <p>{@code listing_id} 에 유일 제약이 있어 결과는 최대 하나로 확정된다.
     */
    Optional<TicketTrade> findByListingId(Long listingId);

    /**
     * 이미 체결된 매물인지 본다.
     *
     * <p>이중 체결을 <b>이 검사로 막지 않는다.</b> 확인과 INSERT 사이에 다른 요청이 끼어들 수 있어,
     * 실제 방어는 매물의 조건부 UPDATE 와 {@code uk_ticket_trade_listing} 제약이 한다.
     * 여기서는 조회·점검용으로만 쓴다.
     */
    boolean existsByListingId(Long listingId);
}
