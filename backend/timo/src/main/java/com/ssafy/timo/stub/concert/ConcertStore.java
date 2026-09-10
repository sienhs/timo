package com.ssafy.timo.stub.concert;

import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.stub.StubFixtures;
import com.ssafy.timo.stub.StubFixtures.ConcertFixture;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Stream;

/**
 * 스텁 공연의 메모리 상태. 고정 공연 4건 위에 이 프로세스에서 생성한 공연과 상태 변경(관리자 종료)을 덧씌운다.
 *
 * <p>공연 상태를 예매·대기열·승계·마켓·관리자 스텁이 함께 보므로 컨트롤러 밖으로 뺐다. 고정 데이터는
 * 불변 레코드라 상태만 따로 기억하고 조회할 때 합쳐 준다.
 */
@Component
@ConditionalOnProperty(prefix = "api.stub", name = "enabled", havingValue = "true")
public class ConcertStore {

    private final AtomicLong idSequence = new AtomicLong(StubFixtures.CREATED_ID_START);
    private final Map<Long, ConcertFixture> created = new ConcurrentHashMap<>();
    private final Map<Long, ConcertStatus> statusOverrides = new ConcurrentHashMap<>();

    public long nextId() {
        return idSequence.getAndIncrement();
    }

    public void save(ConcertFixture concert) {
        created.put(concert.id(), concert);
    }

    public Optional<ConcertFixture> find(long concertId) {
        return StubFixtures.findConcert(concertId)
                .or(() -> Optional.ofNullable(created.get(concertId)))
                .map(this::withOverride);
    }

    public Stream<ConcertFixture> all() {
        return Stream.concat(StubFixtures.CONCERTS.stream(), created.values().stream()).map(this::withOverride);
    }

    public void changeStatus(long concertId, ConcertStatus status) {
        statusOverrides.put(concertId, status);
    }

    private ConcertFixture withOverride(ConcertFixture concert) {
        ConcertStatus status = statusOverrides.get(concert.id());
        if (status == null || status == concert.status()) {
            return concert;
        }
        return new ConcertFixture(concert.id(), concert.title(), concert.genre(), concert.posterImageKey(),
                concert.imageKeys(), concert.description(), concert.ageRating(), status, concert.viewCount(),
                concert.startDate(), concert.endDate(), concert.openAt(), concert.venueId(), concert.venueName(),
                concert.artistIds());
    }
}
