package com.ssafy.timo.domain.seat.service;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.exception.DuplicatedSeatPositionException;
import com.ssafy.timo.domain.seat.exception.SeatPositionOutOfBoundsException;
import com.ssafy.timo.domain.seat.exception.SectionNameDuplicatedException;
import com.ssafy.timo.domain.seat.exception.SeatHoldNotOwnedException;
import com.ssafy.timo.domain.seat.exception.SeatNotHoldableException;
import com.ssafy.timo.domain.seat.exception.SeatNotFoundException;
import com.ssafy.timo.domain.seat.exception.SectionNotFoundException;
import com.ssafy.timo.domain.seat.repository.SectionAvailableCount;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.security.CurrentMemberProvider;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class SeatServiceImpl implements SeatService {

    /** 선점이 유지되는 시간. 결제까지 마칠 만하면서, 놓친 자리가 오래 묶이지 않을 만큼으로 잡았다. */
    private static final Duration HOLD_DURATION = Duration.ofMinutes(5);

    private final SectionRepository sectionRepository;
    private final SeatRepository seatRepository;
    private final VenueRepository venueRepository;
    private final CurrentMemberProvider currentMemberProvider;
    private final Clock clock;

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
     * 공연장의 구역 목록을 잔여석과 함께 돌려준다.
     *
     * <p>개별 좌석은 읽지 않는다. 구역 선택 화면에 필요한 것은 구역당 남은 자리 수뿐이고,
     * 공연장 전체 좌석을 읽으면 수만 건이 된다.
     *
     * <p>잔여석은 구역마다 세지 않고 group by 한 번으로 모아 온다. 구역 수만큼 count 쿼리를
     * 날리면 그게 N+1 이다.
     */
    @Override
    @Transactional(readOnly = true)
    public SectionListResponseDto findSections(Long venueId) {
        Venue venue = venueRepository.findById(venueId)
                .orElseThrow(() -> new VenueNotFoundException(venueId));

        List<Section> sections = sectionRepository.findAllByVenueIdOrderByIdAsc(venueId);
        if (sections.isEmpty()) {
            // 좌석을 아직 등록하지 않은 공연장이다. 오류가 아니므로 빈 목록으로 답한다.
            return SectionListResponseDto.from(venue, sections, Map.of());
        }

        return SectionListResponseDto.from(
                venue, sections, availableCountsOf(sections, LocalDateTime.now(clock)));
    }

    /**
     * 구역 하나의 좌석을 배치도 순서로 돌려준다.
     *
     * <p>페이지로 나누지 않는다. 배치도는 좌석이 전부 있어야 그려진다. 대신 범위가 구역 하나라
     * 응답 크기가 공연장 전체가 아니라 구역 크기로 묶인다.
     */
    @Override
    @Transactional(readOnly = true)
    public SectionSeatListResponseDto findSeats(Long sectionId) {
        Section section = sectionRepository.findById(sectionId)
                .orElseThrow(() -> new SectionNotFoundException(sectionId));

        return SectionSeatListResponseDto.from(
                section,
                seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(sectionId),
                LocalDateTime.now(clock));
    }

    /**
     * 좌석을 선점한다.
     *
     * <p>대상 좌석을 <b>행 잠금과 함께</b> 읽고, 그 잠금 안에서 선점 가능 여부를 확인하고 상태를
     * 바꾼다. 확인과 변경이 한 잠금 안에 있어야 같은 좌석에 대한 동시 선점이 성립하지 않는다.
     *
     * <p>만료된 선점은 그 자리에서 인수한다. 정리 작업을 따로 두지 않았으므로 만료 여부는 기준
     * 시각으로 판단한다.
     *
     * <p>잠그는 순서는 <b>대상 좌석 -> 내가 잡고 있던 좌석</b>이다. 대상이 남의 선점이면 그 지점에서
     * 바로 끝내므로 두 번째 잠금까지 가지 않고, 내가 잡고 있던 좌석은 나만 건드리는 행이라
     * 두 요청이 서로를 기다리는 상황이 생기지 않는다.
     */
    @Override
    public SeatHoldResponseDto hold(Long seatId) {
        Long memberId = currentMemberProvider.currentMemberId();
        LocalDateTime now = LocalDateTime.now(clock);

        Seat seat = seatRepository.findByIdForUpdate(seatId)
                .orElseThrow(() -> new SeatNotFoundException(seatId));

        // 이미 내가 잡고 있는 좌석을 다시 누른 경우다. 만료 시각을 새로 미뤄 준다.
        if (!seat.isHeldBy(memberId, now) && !seat.isHoldableAt(now)) {
            throw new SeatNotHoldableException(seatId);
        }

        Long releasedSeatId = releasePreviousHold(memberId, now, seatId);
        seat.hold(memberId, now.plus(HOLD_DURATION));

        return SeatHoldResponseDto.from(seat, releasedSeatId);
    }

    /**
     * 좌석 선점을 취소한다.
     *
     * <p>선점과 같은 행 잠금 안에서 처리한다. 잠그지 않으면 내가 취소하는 사이 다른 회원의 선점이
     * 끼어들어, 그 사람의 선점을 내가 풀어 버리는 경우가 생긴다.
     *
     * <p>내가 잡고 있는 좌석이면 푼다. 아무도 잡지 않았거나 선점이 만료된 좌석이면 이미 빈 자리이므로
     * 할 일 없이 성공으로 답한다 — 만료 직후에 취소를 눌러도 화면에 오류가 뜨지 않아야 한다.
     * 남이 잡고 있거나 결제까지 끝난 좌석만 거절한다.
     *
     * <p>결제 완료({@link com.ssafy.timo.domain.seat.entity.SeatStatus#OCCUPIED})는 여기서 풀지
     * 않는다. 그것은 선점 해제가 아니라 점유 해제이고, 예매 취소 규칙과 함께 예매 도메인에서 정한다.
     */
    @Override
    public SeatHoldCancelResponseDto cancelHold(Long seatId) {
        Long memberId = currentMemberProvider.currentMemberId();
        LocalDateTime now = LocalDateTime.now(clock);

        Seat seat = seatRepository.findByIdForUpdate(seatId)
                .orElseThrow(() -> new SeatNotFoundException(seatId));

        if (seat.isHeldBy(memberId, now)) {
            seat.releaseHold();
        } else if (!seat.isHoldableAt(now)) {
            // 남의 유효한 선점이거나 결제 완료다. 둘을 구분해 알려주지 않는다.
            throw new SeatHoldNotOwnedException(seatId);
        }

        return SeatHoldCancelResponseDto.from(seat, now);
    }

    /**
     * 한 계정은 좌석 하나만 잡을 수 있으므로, 새로 잡기 전에 이전 선점을 푼다.
     *
     * @return 풀린 좌석 id. 이전 선점이 없었으면 {@code null}.
     */
    private Long releasePreviousHold(Long memberId, LocalDateTime now, Long targetSeatId) {
        List<Seat> previous = seatRepository.findActiveHoldsOfMember(memberId, now, targetSeatId);
        if (previous.isEmpty()) {
            return null;
        }

        previous.forEach(Seat::releaseHold);

        // 규칙상 한 건이다. 어긋난 데이터가 있어도 전부 풀고, 응답에는 가장 최근 것을 알려 준다.
        return previous.get(previous.size() - 1).getId();
    }

    /** 구역 id -> 예매 가능 좌석 수. 남은 자리가 없는 구역은 키가 없으므로 읽는 쪽에서 0 으로 채운다. */
    private Map<Long, Long> availableCountsOf(List<Section> sections, LocalDateTime now) {
        List<Long> sectionIds = sections.stream().map(Section::getId).toList();

        return seatRepository.countAvailableGroupedBySection(sectionIds, now).stream()
                .collect(Collectors.toMap(
                        SectionAvailableCount::sectionId, SectionAvailableCount::availableCount));
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
