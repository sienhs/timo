package com.ssafy.timo.domain.seat.service;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.exception.AlreadyReservedException;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.reservation.service.BookingWindowGuard;
import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatHold;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.exception.DuplicatedSeatPositionException;
import com.ssafy.timo.domain.seat.exception.SeatHoldNotOwnedException;
import com.ssafy.timo.domain.seat.exception.SeatNotFoundException;
import com.ssafy.timo.domain.seat.exception.SeatNotHoldableException;
import com.ssafy.timo.domain.seat.exception.SeatPositionOutOfBoundsException;
import com.ssafy.timo.domain.seat.exception.SectionNameDuplicatedException;
import com.ssafy.timo.domain.seat.exception.SectionNotFoundException;
import com.ssafy.timo.domain.seat.repository.SeatHoldRepository;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SeatWithStatus;
import com.ssafy.timo.domain.seat.repository.SectionAvailableCount;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
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
    private final SeatHoldRepository seatHoldRepository;
    private final ReservationRepository reservationRepository;
    private final VenueRepository venueRepository;
    private final ConcertRepository concertRepository;
    private final MemberRepository memberRepository;
    private final Clock clock;

    @Override
    public CommandSeatResponseDto register(CommandSeatRequestDto request) {
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
     * 이 공연 기준의 구역 목록과 잔여석.
     *
     * <p>공연장이 아니라 공연을 받는다. 잔여석은 공연마다 다르기 때문이다 — 같은 공연장에서 두 공연이
     * 열리면 구역의 남은 자리 수도 각각이다.
     */
    @Override
    @Transactional(readOnly = true)
    public SectionListResponseDto findSections(Long concertId) {
        Concert concert = concertRepository.findByIdWithVenue(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));
        Venue venue = concert.getVenue();

        List<Section> sections = sectionRepository.findAllByVenueIdOrderByIdAsc(venue.getId());
        if (sections.isEmpty()) {
            // 좌석을 아직 등록하지 않은 공연장이다. 오류가 아니므로 빈 목록으로 답한다.
            return SectionListResponseDto.from(venue, sections, Map.of());
        }

        return SectionListResponseDto.from(
                venue, sections, availableCountsOf(concertId, sections, LocalDateTime.now(clock)));
    }

    /**
     * 이 공연 기준의 구역 좌석 배치도.
     *
     * <p>좌석마다 선점·주문을 따로 묻지 않는다. 한 쿼리에서 LEFT JOIN 두 번으로 상태까지 받아 온다 —
     * 구역 좌석이 수천 건이라 좌석당 조회를 돌면 그게 N+1 이다.
     */
    @Override
    @Transactional(readOnly = true)
    public SectionSeatListResponseDto findSeats(Long concertId, Long sectionId) {
        Concert concert = concertRepository.findById(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));
        Section section = sectionRepository.findById(sectionId)
                .orElseThrow(() -> new SectionNotFoundException(sectionId));
        verifySectionBelongsTo(concert, section);

        return SectionSeatListResponseDto.from(
                section,
                seatRepository.findSeatsWithStatus(concertId, sectionId, LocalDateTime.now(clock)));
    }

    /**
     * 좌석을 선점한다.
     *
     * <p>예매 중(ON_SALE)이면서 지금이 예매 가능한 시간 창 안({@link Concert#bookingBlockReason})인
     * 공연만 선점할 수 있다. 오픈 전·마감 후·매진·종료·취소된 공연은 좌석이 남아 있어도(혹은 아직
     * 없어도) 선점이 성립하지 않는다. 선점이 열려 있어도 결제 시점에는 마감이 지나 있을 수 있으므로
     * {@link com.ssafy.timo.domain.reservation.service.ReservationServiceImpl#create}가 같은 판정을
     * 한 번 더 한다.
     *
     * <p>이 공연의 티켓을 이미 산 회원은 다른 자리를 선점할 수 없다("1인 1매"). 지금 잡고 있는
     * 내 선점을 다시 누르는 것과는 다른 얘기다 — 그건 결제 전 단계라 여기 걸리지 않는다.
     *
     * <p>취소 뒤 해제를 기다리는 자리는 <b>아무도</b> 선점할 수 없다. 취소한 본인도 마찬가지다 —
     * 예외를 두면 취소하고 곧바로 되잡는 길이 열려 랜덤 지연을 우회할 수 있다. 조회에서는 선점처럼
     * 보이는 자리라, 여기서 안 막으면 화면엔 잡힌 자리를 API 로 직접 잡는 통로가 남는다.
     *
     * <p>좌석 행을 잠그지 않는다. 좌석은 모든 공연이 공유하는 한 행이라 거기 잠금을 걸면 서로 다른
     * 공연의 선점 요청이 같은 줄에 선다. 대신 {@code seat_hold} INSERT 를 시도하고,
     * {@code uk_hold_seat} 에 걸리면 진 것으로 본다. 충돌은 <b>같은 공연의 같은 좌석</b>에서만 난다.
     *
     * <p>넣기 전에 만료된 선점을 정리한다. 유니크 인덱스는 만료 여부를 모르고 {@code status='HELD'} 만
     * 보므로, 정리하지 않으면 <b>이미 풀린 선점 때문에</b> 새 선점이 거절된다.
     */
    @Override
    public SeatHoldResponseDto hold(Long memberId, Long concertId, Long seatId) {
        LocalDateTime now = LocalDateTime.now(clock);

        // 새 선점의 유니크 제약에 충돌할 수 있는 행만 정리한다. 공연 전체의 만료 선점을 여기서
        // 매번 갱신하면 동시 선점이 몰릴 때 불필요한 전역 UPDATE와 DB 커넥션 점유가 생긴다.
        seatHoldRepository.expireStaleForSeat(concertId, seatId, now);
        seatHoldRepository.expireStaleForMember(concertId, memberId, now);

        Concert concert = concertRepository.findById(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));
        BookingWindowGuard.check(concert, now);
        if (reservationRepository.findPaidOfMember(concertId, memberId).isPresent()) {
            throw new AlreadyReservedException(concertId);
        }
        Seat seat = seatRepository.findById(seatId)
                .orElseThrow(() -> new SeatNotFoundException(seatId));
        verifySectionBelongsTo(concert, seat.getSection());

        // 팔린 자리는 선점 유니크에 걸리지 않으므로 따로 막는다.
        if (reservationRepository.existsPaidSeat(concertId, seatId)) {
            throw new SeatNotHoldableException(seatId);
        }
        // 해제를 기다리는 취소 자리다. 조회에서 선점처럼 보이므로 여기서도 막아야 API 직접 호출로
        // 뚫리지 않는다. 해제 시각이 지났으면 그냥 빈 자리다.
        if (reservationRepository.existsSeatAwaitingRelease(concertId, seatId, now)) {
            throw new SeatNotHoldableException(seatId);
        }

        // 이미 내가 잡고 있는 자리를 다시 누른 경우다. 새로 넣으면 내 선점에 스스로 걸리므로 미뤄만 준다.
        Optional<SeatHold> onSeat = seatHoldRepository.findActive(concertId, seatId, now);
        if (onSeat.isPresent()) {
            SeatHold existing = onSeat.get();
            if (!existing.isOwnedBy(memberId)) {
                throw new SeatNotHoldableException(seatId);
            }
            existing.extendTo(now.plus(HOLD_DURATION));
            return SeatHoldResponseDto.from(seat, existing, null);
        }

        Long releasedSeatId = releasePreviousHold(concertId, memberId, now);

        SeatHold hold = SeatHold.builder()
                .concert(concert)
                .seat(seat)
                .member(memberRepository.getReferenceById(memberId))
                .expiresAt(now.plus(HOLD_DURATION))
                .build();

        try {
            // flush 까지 해야 유니크 위반이 이 자리에서 난다. save 만 하면 트랜잭션 커밋 시점에 터진다.
            seatHoldRepository.saveAndFlush(hold);
        } catch (DataIntegrityViolationException e) {
            // 같은 순간 다른 요청이 이 자리를 먼저 가져갔다.
            throw new SeatNotHoldableException(seatId);
        }

        return SeatHoldResponseDto.from(seat, hold, releasedSeatId);
    }

    /**
     * 선점을 취소한다.
     *
     * <p>내 선점이면 푼다. 아무도 잡지 않았거나 이미 만료된 자리면 할 일 없이 성공으로 답한다 —
     * 만료 직후에 취소를 눌러도 화면에 오류가 뜨면 안 된다. 남의 선점과 팔린 자리만 거절한다.
     */
    @Override
    public SeatHoldCancelResponseDto cancelHold(Long memberId, Long concertId, Long seatId) {
        LocalDateTime now = LocalDateTime.now(clock);

        // 취소 판단에는 이 좌석의 유효한 선점만 필요하다. 다른 좌석의 만료 선점까지 갱신하지 않는다.
        seatHoldRepository.expireStaleForSeat(concertId, seatId, now);

        Concert concert = concertRepository.findById(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));
        Seat seat = seatRepository.findById(seatId)
                .orElseThrow(() -> new SeatNotFoundException(seatId));
        verifySectionBelongsTo(concert, seat.getSection());

        Optional<SeatHold> active = seatHoldRepository.findActive(concertId, seatId, now);
        if (active.isPresent()) {
            if (!active.get().isOwnedBy(memberId)) {
                throw new SeatHoldNotOwnedException(seatId);
            }
            active.get().release(now);
        } else if (reservationRepository.existsPaidSeat(concertId, seatId)) {
            // 이미 팔린 자리다. 선점 취소로 풀 수 있는 상태가 아니다.
            throw new SeatHoldNotOwnedException(seatId);
        }

        return SeatHoldCancelResponseDto.from(seat);
    }

    @Override
    @Transactional(readOnly = true)
    public long countAvailable(Long concertId) {
        if (!concertRepository.existsById(concertId)) {
            throw new ConcertNotFoundException(concertId);
        }
        return seatRepository.countAvailable(concertId, LocalDateTime.now(clock));
    }

    /**
     * 한 계정은 한 공연에서 좌석 하나만 잡을 수 있으므로, 새로 잡기 전에 이전 선점을 푼다.
     *
     * <p>풀지 않고 넣으면 {@code uk_hold_member} 에 걸린다. 공연이 다르면 서로 영향이 없다.
     *
     * @return 풀린 좌석 id. 이전 선점이 없었으면 {@code null}
     */
    private Long releasePreviousHold(Long concertId, Long memberId, LocalDateTime now) {
        Optional<SeatHold> previous = seatHoldRepository.findActiveOfMember(concertId, memberId, now);
        if (previous.isEmpty()) {
            return null;
        }

        SeatHold hold = previous.get();
        hold.release(now);
        // 유니크 재료인 생성 칼럼이 갱신돼야 새 선점이 들어갈 수 있다.
        seatHoldRepository.flush();

        return hold.getSeat().getId();
    }

    /** 구역 id -> 이 공연의 예매 가능 좌석 수. 남은 자리가 없는 구역은 키가 없으므로 읽는 쪽에서 0 으로 채운다. */
    private Map<Long, Long> availableCountsOf(Long concertId, List<Section> sections, LocalDateTime now) {
        List<Long> sectionIds = sections.stream().map(Section::getId).toList();

        return seatRepository.countAvailableGroupedBySection(concertId, sectionIds, now).stream()
                .collect(Collectors.toMap(
                        SectionAvailableCount::sectionId, SectionAvailableCount::availableCount));
    }

    /**
     * 이 공연이 열리는 공연장의 구역인지 확인한다.
     *
     * <p>없으면 다른 공연장의 좌석을 이 공연으로 선점할 수 있다. 좌석과 공연이 각각 존재하기만 하면
     * 조인 조건은 통과하므로, 둘의 관계를 여기서 따로 봐야 한다.
     */
    private void verifySectionBelongsTo(Concert concert, Section section) {
        if (!section.getVenue().getId().equals(concert.getVenue().getId())) {
            throw new SectionNotFoundException(section.getId());
        }
    }

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
