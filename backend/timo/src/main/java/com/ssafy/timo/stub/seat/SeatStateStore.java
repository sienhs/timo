package com.ssafy.timo.stub.seat;

import com.ssafy.timo.domain.seat.entity.SeatStatus;
import com.ssafy.timo.stub.StubFixtures;
import com.ssafy.timo.stub.StubFixtures.SeatFixture;
import com.ssafy.timo.stub.StubFixtures.SectionFixture;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

/**
 * 스텁 좌석의 메모리 상태.
 *
 * <p>고정 배치도({@link StubFixtures#initialStatus}) 위에 이 프로세스에서 한 선점·점유만 덧씌운다.
 * 덧씌운 좌석은 전부 "내 것" 으로, 고정 배치도에서 이미 {@code RESERVED}·{@code OCCUPIED} 인 좌석은
 * "남의 것" 으로 본다. 로컬에는 요청자 개념이 없어 이렇게 갈라야 403 과 409 분기를 둘 다 보여 줄 수 있다.
 *
 * <p>실제 규칙대로 선점은 한 자리만 유지된다. 새 자리를 잡으면 이전 선점이 풀리고 그 id 를 알려 준다.
 *
 * <p>구역 스텁과 좌석 스텁이 같은 상태를 봐야 하므로 컨트롤러 밖으로 뺐다. 스텁과 같은 조건으로 뜬다.
 */
@Component
@ConditionalOnProperty(prefix = "api.stub", name = "enabled", havingValue = "true")
public class SeatStateStore {

    /** 내가 바꾼 좌석의 현재 상태. 여기 없는 좌석은 고정 배치도의 초기 상태다. */
    private final Map<Long, SeatStatus> mine = new ConcurrentHashMap<>();

    /**
     * 현재 유지 중인 내 선점. 점유로 넘어가면 비운다.
     *
     * <p>{@code AtomicReference<Long>} 을 쓰지 않는다. {@code compareAndSet} 이 참조 동일성으로 비교해
     * 127 을 넘는 좌석 id 는 같은 값이어도 다른 객체로 판정된다. 쓰는 메서드가 전부 synchronized 라
     * 평범한 필드로 충분하다.
     */
    private Long heldSeatId;

    public Optional<SeatFixture> find(long seatId) {
        return StubFixtures.findSeat(seatId);
    }

    public SeatStatus statusOf(SeatFixture seat) {
        return mine.getOrDefault(seat.id(), seat.initialStatus());
    }

    public boolean isMine(SeatFixture seat) {
        return mine.containsKey(seat.id());
    }

    /** 이 자리를 내 선점으로 바꾼다. 다른 자리를 잡고 있었다면 풀고 그 id 를 돌려준다. */
    public synchronized Long hold(SeatFixture seat) {
        Long previous = heldSeatId;
        heldSeatId = seat.id();
        mine.put(seat.id(), SeatStatus.HELD);

        if (previous == null || previous.equals(seat.id())) {
            return null;    // 처음 잡았거나 같은 자리를 다시 잡아 만료만 늘린 경우.
        }
        mine.remove(previous);
        return previous;
    }

    public synchronized void release(SeatFixture seat) {
        mine.remove(seat.id());
        clearHeldIf(seat);
    }

    public synchronized void occupy(SeatFixture seat) {
        mine.put(seat.id(), SeatStatus.SOLD);
        clearHeldIf(seat);
    }

    private void clearHeldIf(SeatFixture seat) {
        if (Objects.equals(heldSeatId, seat.id())) {
            heldSeatId = null;
        }
    }

    public int availableCount(SectionFixture section) {
        int count = 0;
        for (int seatNo = 1; seatNo <= section.rowCount(); seatNo++) {
            for (int seatCol = 1; seatCol <= section.seatPerRow(); seatCol++) {
                if (!StubFixtures.hasSeat(section, seatNo, seatCol)) {
                    continue;
                }
                SeatFixture seat = StubFixtures.findSeat(StubFixtures.seatId(section, seatNo, seatCol)).orElseThrow();
                if (statusOf(seat) == SeatStatus.AVAILABLE) {
                    count++;
                }
            }
        }
        return count;
    }
}
