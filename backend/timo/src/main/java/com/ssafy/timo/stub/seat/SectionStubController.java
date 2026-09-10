package com.ssafy.timo.stub.seat;

import com.ssafy.timo.domain.seat.controller.SectionApi;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto.SectionSummary;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.stub.StubController;
import com.ssafy.timo.stub.StubFixtures;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;

import java.util.List;

/**
 * 구역 API 스텁 (v0).
 *
 * <p>어느 공연장 id 를 보내도 고정 구역 3개를 돌려준다. 잔여석은 {@link SeatStateStore} 의 현재 상태로
 * 세므로, v0 로 좌석을 선점하면 이 목록의 {@code availableCount} 도 하나 줄어든다.
 */
@StubController
@RequestMapping(SectionStubController.BASE_PATH)
public class SectionStubController implements SectionApi {

    static final String BASE_PATH = "/api/v0/sections";

    private final SeatStateStore seatStateStore;

    public SectionStubController(SeatStateStore seatStateStore) {
        this.seatStateStore = seatStateStore;
    }

    @Override
    public ResponseEntity<SectionListResponseDto> findSections(Long venueId) {
        if (venueId == StubFixtures.NOT_FOUND_ID) {
            throw new VenueNotFoundException(venueId);
        }

        List<SectionSummary> sections = StubFixtures.SECTIONS.stream()
                .map(section -> new SectionSummary(
                        section.id(),
                        section.name(),
                        StubFixtures.SEAT_GRADE,
                        section.price(),
                        section.seatCount(),
                        seatStateStore.availableCount(section),
                        section.rowCount(),
                        section.seatPerRow()))
                .toList();

        return ResponseEntity.ok(new SectionListResponseDto(
                venueId,
                StubFixtures.VENUE_NAME,
                sections.stream().mapToInt(SectionSummary::seatCount).sum(),
                sections.stream().mapToInt(SectionSummary::availableCount).sum(),
                sections));
    }
}
