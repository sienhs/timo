package com.ssafy.timo.domain.seat.service;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.exception.DuplicatedSeatPositionException;
import com.ssafy.timo.domain.seat.exception.SeatPositionOutOfBoundsException;
import com.ssafy.timo.domain.seat.exception.SectionNameDuplicatedException;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Transactional
public class SeatServiceImpl implements SeatService {

    private final SectionRepository sectionRepository;
    private final SeatRepository seatRepository;
    private final VenueRepository venueRepository;

    /**
     * 공연장의 구역과 좌석을 등록한다.
     *
     * <p>한 트랜잭션이므로 구역 하나라도 실패하면 앞서 만들어진 좌석까지 함께 롤백된다.
     */
    @Override
    public CommandSeatResponseDto register(CommandSeatRequestDto request) {
        // 응답에 공연장 이름을 실어야 해서 참조만 만드는 대신 실제로 조회한다.
        Venue venue = venueRepository.findById(request.venueId())
                .orElseThrow(() -> new VenueNotFoundException(request.venueId()));

        validateNamesNotDuplicated(request);

        List<Section> sections = new ArrayList<>(request.sections().size());
        for (CommandSeatRequestDto.SectionLayout layout : request.sections()) {
            sections.add(registerSection(venue, layout));
        }

        return CommandSeatResponseDto.from(venue, sections);
    }

    /**
     * 구역 하나와 그 좌석을 만든다.
     *
     * <p>배치도 격자 크기를 보내지 않았으면 좌석 목록의 최대 번호에서 뽑아낸다. 이 값은 배치도를 그리는
     * 용도이므로 실제 좌석 수({@code seatCount})와 같지 않을 수 있다.
     */
    private Section registerSection(Venue venue, CommandSeatRequestDto.SectionLayout layout) {
        List<SeatPosition> positions = layout.toPositions();
        validatePositions(layout, positions);

        Section section = sectionRepository.save(Section.builder()
                .name(layout.name())
                .price(layout.price())
                .rowCount(layout.rowCount() != null ? layout.rowCount() : maxSeatNo(positions))
                .seatPerRow(layout.seatPerRow() != null ? layout.seatPerRow() : maxSeatCol(positions))
                .venue(venue)
                .build());

        seatRepository.saveAll(section.createSeats(positions));

        return section;
    }

    /**
     * 나열된 자리를 검사한다. 같은 자리가 두 번 들어왔는지, 그리고 선언한 격자 크기를 벗어난 자리가 있는지 본다.
     *
     * <p>중복을 미리 걸러내는 이유는 {@code uk_seat_section_position} 제약에 걸려 500 이 되는 것을 막기 위해서다.
     * 격자 범위 검사는 격자 크기를 함께 보낸 경우에만 한다. 생략했다면 좌석 목록이 곧 기준이므로 벗어날 것이 없다.
     */
    private void validatePositions(CommandSeatRequestDto.SectionLayout layout,
                                   List<SeatPosition> positions) {
        Set<SeatPosition> seen = new HashSet<>();

        for (SeatPosition position : positions) {
            if (!seen.add(position)) {
                throw new DuplicatedSeatPositionException(layout.name(), position);
            }

            boolean outOfRows = layout.rowCount() != null && position.seatNo() > layout.rowCount();
            boolean outOfCols = layout.seatPerRow() != null && position.seatCol() > layout.seatPerRow();
            if (outOfRows || outOfCols) {
                throw new SeatPositionOutOfBoundsException(
                        layout.name(), position, layout.rowCount(), layout.seatPerRow());
            }
        }
    }

    /**
     * 구역명 중복을 걸러낸다. 이미 등록된 것과 겹치는 경우, 그리고 같은 요청 안에서 겹치는 경우 둘 다 본다.
     *
     * <p>최종 방어선은 {@code uk_section_venue_name} 제약이다. 여기서는 흔한 경우를 409 로 먼저 걸러낸다.
     * 요청 안의 중복까지 보는 이유는, 그대로 두면 제약에 걸려 500 이 되기 때문이다.
     */
    private void validateNamesNotDuplicated(CommandSeatRequestDto request) {
        Set<String> namesInRequest = new HashSet<>();

        for (CommandSeatRequestDto.SectionLayout layout : request.sections()) {
            if (!namesInRequest.add(layout.name())) {
                throw new SectionNameDuplicatedException(layout.name());
            }

            if (sectionRepository.existsByVenueIdAndName(request.venueId(), layout.name())) {
                throw new SectionNameDuplicatedException(layout.name());
            }
        }
    }

    private int maxSeatNo(List<SeatPosition> positions) {
        return positions.stream().mapToInt(SeatPosition::seatNo).max().orElseThrow();
    }

    private int maxSeatCol(List<SeatPosition> positions) {
        return positions.stream().mapToInt(SeatPosition::seatCol).max().orElseThrow();
    }
}
