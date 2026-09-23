package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.blockchain.ShowRegistryClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;

import jakarta.persistence.EntityManager;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigInteger;
import java.time.Clock;
import java.util.List;

/**
 * {@code ProdCatalogSeeder}가 공연 하나씩 온체인에 등록할 때 위임하는 협력 빈.
 *
 * <p>별도 빈으로 뽑은 이유가 있다 - {@code ProdCatalogSeeder.run()}이 이 메서드를 자기 자신의
 * 메서드처럼(같은 클래스 안에서 {@code this.registerOne(...)}) 불렀다면 프록시를 안 거쳐
 * {@code @Transactional}이 조용히 무시된다(자기 호출 문제, {@code ReservationSettlementRunner}와
 * 같은 사정). 진짜 다른 빈을 거쳐야 트랜잭션 프록시가 실제로 걸린다.
 *
 * <p>그리고 이렇게 나누는 게 자기 호출 회피 때문만은 아니다 - ON_SALE 공연 수십 건을 <b>하나의
 * 트랜잭션</b> 안에서 순차적으로 온체인 등록하면(공연 하나당 실제 네트워크 왕복이 있는 트랜잭션이라
 * 수십 초~수 분이 걸릴 수 있다), 그 긴 트랜잭션이 {@code concert} 테이블 행을 물고 있는 동안
 * {@code ConcertStatusScheduler}(1분마다 도는 별도 스케줄러)가 같은 테이블에 조건부 UPDATE를
 * 시도하다 잠금 대기로 막힐 수 있다. 공연마다 트랜잭션을 짧게 끊으면 이 위험이 사라진다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
class ProdShowRegistrar {

    private final ConcertRepository concertRepository;
    private final ShowRegistryClient showRegistryClient;
    private final EntityManager entityManager;
    private final Clock clock;

    /**
     * 공연 하나를 온체인에 등록한다. 실패해도 이 공연만 {@code SCHEDULED}로 되돌아갈 뿐, 트랜잭션이
     * 이 공연 하나에만 걸려 있어 다른 공연이나 이미 등록된 것들에는 영향이 없다.
     *
     * @return 등록에 성공했으면 {@code true}
     */
    @Transactional
    boolean registerOne(Long concertId, Member organizer, List<BigInteger> sectionPrices, BigInteger totalSeats) {
        Concert concert = concertRepository.getReferenceById(concertId);
        try {
            long saleOpenTime = concert.getOpenAt().atZone(clock.getZone()).toEpochSecond();
            long showTime = concert.getStartDate().atZone(clock.getZone()).toEpochSecond();
            BigInteger showId = showRegistryClient.registerShow(
                    sectionPrices, totalSeats, saleOpenTime, showTime, "prod-seed:" + concert.getTitle());

            concert.prepareForSale(organizer);
            concert.confirmRegistered(showId);
            return true;
        } catch (ContractCallException e) {
            // ON_SALE 인데 isReadyForBooking() 이 false 인 상태를 남기면
            // ReservationServiceImpl.create() 가 그걸 불변식 위반(500)으로 던지므로, "체인 미등록"은
            // 항상 "아직 판매 전"(409)으로 보여야 한다(LocalDataSeeder와 같은 이유).
            log.warn("공연 '{}' 온체인 등록 실패, SCHEDULED 로 되돌린다 - 체인 접근(방화벽·키)을 확인하라",
                    concert.getTitle(), e);
            entityManager.createQuery(
                            "update Concert c set c.status = com.ssafy.timo.domain.concert.entity.ConcertStatus.SCHEDULED "
                                    + "where c.id = :id")
                    .setParameter("id", concertId)
                    .executeUpdate();
            return false;
        }
    }
}
