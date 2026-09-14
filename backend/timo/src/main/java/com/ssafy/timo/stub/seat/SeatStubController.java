package com.ssafy.timo.stub.seat;

import com.ssafy.timo.domain.seat.controller.SeatApi;
import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto.SectionLayout;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto.SeatSummary;
import com.ssafy.timo.domain.seat.entity.SeatStatus;
import com.ssafy.timo.domain.seat.exception.SeatHoldNotOwnedException;
import com.ssafy.timo.domain.seat.exception.SeatNotFoundException;
import com.ssafy.timo.domain.seat.exception.SeatNotHoldableException;
import com.ssafy.timo.domain.seat.exception.SectionNameDuplicatedException;
import com.ssafy.timo.domain.seat.exception.SectionNotFoundException;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.stub.StubController;
import com.ssafy.timo.stub.StubFixtures;
import com.ssafy.timo.stub.StubFixtures.SeatFixture;
import com.ssafy.timo.stub.StubFixtures.SectionFixture;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.atomic.AtomicLong;

/**
 * 좌석 API 스텁 (v0).
 *
 * <p>좌석 조회는 고정 구역 3개({@link StubFixtures#SECTIONS})만 안다. 선점·점유는
 * {@link SeatStateStore} 에 기억해 두어, 잡은 자리를 다시 조회하면 {@code RESERVED} 로 보인다.
 *
 * <p>403 / 409 분기 규칙은 {@link SeatStateStore} 의 "내 것 / 남의 것" 구분을 따른다.
 * 고정 배치도에서 처음부터 {@code RESERVED}·{@code OCCUPIED} 인 자리를 건드리면 403,
 * 잡지 않은 빈 자리를 점유하려 하면 409 다.
 */
@StubController
@RequestMapping(SeatStubController.BASE_PATH)
public class SeatStubController implements SeatApi {

    static final String BASE_PATH = "/api/v0/seats";

    private final SeatStateStore seatStateStore;
    private final Clock clock;
    private final AtomicLong sectionIdSequence = new AtomicLong(StubFixtures.CREATED_ID_START);

    public SeatStubController(SeatStateStore seatStateStore, Clock clock) {
        this.seatStateStore = seatStateStore;
        this.clock = clock;
    }

    @Override
    public ResponseEntity<SectionSeatListResponseDto> findSeats(Long concertId, Long sectionId) {
        SectionFixture section = StubFixtures.findSection(sectionId)
                .orElseThrow(() -> new SectionNotFoundException(sectionId));

        List<SeatSummary> seats = new ArrayList<>();
        for (int seatNo = 1; seatNo <= section.rowCount(); seatNo++) {
            for (int seatCol = 1; seatCol <= section.seatPerRow(); seatCol++) {
                if (!StubFixtures.hasSeat(section, seatNo, seatCol)) {
                    continue;
                }
                SeatFixture seat = seatStateStore.find(StubFixtures.seatId(section, seatNo, seatCol)).orElseThrow();
                seats.add(new SeatSummary(seat.id(), seatNo, seatCol, seatStateStore.statusOf(seat)));
            }
        }

        return ResponseEntity.ok(new SectionSeatListResponseDto(
                section.id(),
                section.name(),
                StubFixtures.SEAT_GRADE,
                section.price(),
                seats.size(),
                (int) seats.stream().filter(seat -> seat.status() == SeatStatus.AVAILABLE).count(),
                section.rowCount(),
                section.seatPerRow(),
                seats));
    }

    @Override
    public ResponseEntity<SeatHoldResponseDto> hold(Long seatId, Long concertId) {
        SeatFixture seat = findSeat(seatId);
        if (!seatStateStore.isMine(seat) && seatStateStore.statusOf(seat) != SeatStatus.AVAILABLE) {
            throw new SeatNotHoldableException(seatId);
        }
        if (seatStateStore.isMine(seat) && seatStateStore.statusOf(seat) == SeatStatus.SOLD) {
            throw new SeatNotHoldableException(seatId);
        }

        Long releasedSeatId = seatStateStore.hold(seat);
        LocalDateTime heldUntil = LocalDateTime.now(clock).plusMinutes(StubFixtures.HOLD_MINUTES);

        return ResponseEntity.ok(new SeatHoldResponseDto(
                seat.id(),
                seat.section().id(),
                seat.section().name(),
                seat.seatNo(),
                seat.seatCol(),
                SeatStatus.HELD,
                heldUntil,
                releasedSeatId));
    }

    @Override
    public ResponseEntity<SeatHoldCancelResponseDto> cancelHold(Long seatId, Long concertId) {
        SeatFixture seat = findSeat(seatId);
        SeatStatus status = seatStateStore.statusOf(seat);

        if (seatStateStore.isMine(seat)) {
            if (status == SeatStatus.SOLD) {
                throw new SeatHoldNotOwnedException(seatId);   // 결제까지 끝난 자리는 선점 취소로 못 푼다.
            }
            seatStateStore.release(seat);
        } else if (status != SeatStatus.AVAILABLE) {
            throw new SeatHoldNotOwnedException(seatId);       // 남이 잡았거나 팔린 자리.
        }

        return ResponseEntity.ok(new SeatHoldCancelResponseDto(
                seat.id(),
                seat.section().id(),
                seat.section().name(),
                seat.seatNo(),
                seat.seatCol(),
                SeatStatus.AVAILABLE));
    }

    /**
     * 구역·좌석 등록. 응답만 만들고 배치도에는 반영하지 않는다.
     *
     * <p>등록한 구역을 곧바로 조회까지 이어 주려면 배치도 전체를 메모리 모델로 옮겨야 하는데,
     * 그 화면(관리자 등록)은 조회 화면과 같은 흐름에 있지 않아 스텁에서는 값을 맞추는 데서 멈춘다.
     * {@code rowCount}·{@code seatPerRow} 를 생략했을 때 좌석 최대 번호로 채우는 규칙은 실제와 같다.
     */
    @Override
    public ResponseEntity<CommandSeatResponseDto> register(CommandSeatRequestDto request) {
        if (request.venueId() == StubFixtures.NOT_FOUND_ID) {
            throw new VenueNotFoundException(request.venueId());
        }

        Set<String> names = new HashSet<>();
        List<CommandSeatResponseDto.SectionSummary> sections = new ArrayList<>();
        for (SectionLayout layout : request.sections()) {
            if (!names.add(layout.name())) {
                throw new SectionNameDuplicatedException(layout.name());
            }
            int rowCount = layout.rowCount() != null
                    ? layout.rowCount()
                    : layout.seats().stream().mapToInt(seat -> seat.seatNo()).max().orElse(0);
            int seatPerRow = layout.seatPerRow() != null
                    ? layout.seatPerRow()
                    : layout.seats().stream().mapToInt(seat -> seat.seatCol()).max().orElse(0);

            sections.add(new CommandSeatResponseDto.SectionSummary(
                    sectionIdSequence.getAndIncrement(),
                    layout.name(),
                    StubFixtures.SEAT_GRADE,
                    layout.price(),
                    layout.seats().size(),
                    rowCount,
                    seatPerRow));
        }

        return ResponseEntity
                .status(HttpStatus.CREATED)
                .body(new CommandSeatResponseDto(
                        request.venueId(),
                        StubFixtures.VENUE_NAME,
                        sections.stream().mapToInt(CommandSeatResponseDto.SectionSummary::seatCount).sum(),
                        sections));
    }

    private SeatFixture findSeat(Long seatId) {
        return seatStateStore.find(seatId).orElseThrow(() -> new SeatNotFoundException(seatId));
    }

}
