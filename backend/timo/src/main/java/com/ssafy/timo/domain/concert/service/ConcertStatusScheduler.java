package com.ssafy.timo.domain.concert.service;

import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;

/**
 * 공연 상태 컬럼을 날짜에 맞춰 밀어 준다.
 *
 * <p><b>예매 가능 여부의 근거가 아니다.</b> 선점과 결제는 {@code Concert.bookingBlockReason} 이
 * 요청마다 날짜로 유도한 판정만 쓰고 이 컬럼을 보지 않는다. 그래서 잡이 1분 늦거나 배포로 한동안
 * 돌지 않았어도 돈이 오가는 경로는 틀리지 않는다. 이 컬럼이 돌보는 것은 목록 필터
 * ({@code ConcertRepository.findPage} 의 {@code status} 조건)와 화면에 찍히는 라벨뿐이다.
 *
 * <p>판정은 유도로 두고 컬럼은 캐시로 남긴 이유. 컬럼을 아예 없애고 전부 유도하면 갱신할 값이
 * 사라져 더 깔끔하지만, 그러면 "예매 중인 공연 목록" 이 날짜 조건 여러 개로 풀려 홈 화면의 주력
 * 쿼리가 인덱스를 타기 어려워진다. 정확성이 필요한 곳은 유도, 검색이 필요한 곳은 컬럼으로 역할을
 * 나눈다. 컬럼이 잠깐 낡아도 안전한 것은 판정이 컬럼을 믿지 않기 때문이다.
 *
 * <p>{@code SOLD_OUT} 도 여기서 함께 민다. 원인이 시간이 아니라 재고라 결제 트랜잭션 안에서
 * 쓰는 쪽이 자연스러워 보이지만, 그러면 마지막 두 자리를 동시에 결제할 때 두 트랜잭션이 서로의
 * 미확정 행을 보지 못해 <b>아무도</b> 매진으로 넘기지 못한다. 잠금이나 별도 장치가 필요해지고,
 * 그 비용이 하필 가장 붐비는 결제 경로에 붙는다. 여기서 조건부 UPDATE 로 미루면 그 문제가 통째로
 * 사라진다 - 늦어도 1분이면 맞춰지고, 그동안 매진 공연이 팔릴 위험도 없다. 좌석 선점이
 * {@code SeatServiceImpl.hold} 에서 이미 자리 단위로 막고, 좌석 조회도 잔여 0 을 정확히 보여준다.
 * 즉 이 전이가 늦어서 생기는 일은 목록과 라벨이 잠깐 낡는 것뿐이다.
 *
 * <p>매진은 되돌아온다. 취소가 나면 그 자리는 해제 시각이 지난 뒤 다시 팔리므로
 * 매진 공연이 예매 중으로 돌아가야 한다. 취소 쪽에서 상태를 쓰지 않고 여기서
 * 양방향을 함께 보는 이유는 매진 쪽과 같다 - 취소 트랜잭션이 재고 전체를 알아야 할 이유가 없고,
 * 같은 조건을 뒤집은 쿼리 하나면 끝난다.
 *
 * <p>{@code CANCELED} 는 건드리지 않는다 - 사람이 내린 결정을 시간이 되돌릴 수는 없다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class ConcertStatusScheduler {

    /**
     * 1분. 이 값이 곧 <b>라벨이 늦을 수 있는 최대 시간</b>이다.
     *
     * <p>더 짧게 할 이유가 없다. 오픈 직후에 예매가 되는지는 잡이 아니라 유도 판정이 답하므로,
     * 주기를 줄여서 줄어드는 것은 목록에 "예매 중" 이 찍히는 시점뿐이다.
     */
    private static final long SWEEP_INTERVAL_MILLIS = 60_000L;

    private final ConcertRepository concertRepository;
    private final Clock clock;

    /**
     * 끝난 공연을 먼저 닫고, 그다음에 오픈 시각이 지난 공연을 연다.
     *
     * <p>순서가 이래야 한 번만 쓴다. 여는 쪽을 먼저 하면 오픈 시각과 종료 시각이 모두 지난 공연이
     * {@code SCHEDULED → ON_SALE → CLOSED} 로 두 번 갱신된다. 닫는 쪽을 먼저 하면 그 공연은 바로
     * {@code CLOSED} 가 되고, 여는 쿼리는 {@code SCHEDULED} 만 노리므로 다시 열리지 않는다.
     *
     * <p>{@code initialDelay = 0} 으로 기동 직후에도 한 번 돈다. 서버가 내려가 있던 동안은 아무도
     * 상태를 밀지 않았으므로 그 공백을 뜨는 즉시 메꿔야 한다.
     *
     * <p>인스턴스가 여러 대여도 락이 필요 없다. 두 쿼리 모두 조건부 UPDATE 라 같은 시각에 여러 번
     * 돌아도 결과가 같다. 서로 같은 행을 잡으면 늦은 쪽이 0건을 돌려줄 뿐이다.
     */
    @Scheduled(initialDelay = 0L, fixedDelay = SWEEP_INTERVAL_MILLIS)
    @Transactional
    public void sweep() {
        LocalDateTime now = LocalDateTime.now(clock);

        int closed = concertRepository.closeFinished(now);
        int opened = concertRepository.openScheduled(now);
        // 재고 판정은 시간 판정 다음이다. 둘 다 ON_SALE / SOLD_OUT 만 건드리므로, 이번 틱에 막
        // 열린 공연도 같은 틱에서 매진까지 갈 수 있다(좌석이 미리 다 팔려 있던 경우).
        //
        // 되돌리는 쪽을 매진 판정보다 먼저 돌린다. 순서가 반대면 방금 매진으로 넘긴 공연을 같은
        // 틱에서 다시 들여다보게 되어, 한 공연에 두 번 쓰는 경우가 생긴다.
        int reopened = concertRepository.reopenSoldOut();
        int soldOut = concertRepository.markSoldOut();

        if (closed > 0 || opened > 0 || reopened > 0 || soldOut > 0) {
            // 아무 일도 없는 대부분의 틱은 남기지 않는다. 1분마다 찍으면 로그가 이것만 남는다.
            log.info("공연 상태를 갱신했다 (opened={}, closed={}, soldOut={}, reopened={}, now={})",
                    opened, closed, soldOut, reopened, now);
        }
    }
}
