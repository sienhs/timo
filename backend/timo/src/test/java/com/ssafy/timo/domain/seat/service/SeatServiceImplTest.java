package com.ssafy.timo.domain.seat.service;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.seat.entity.SeatStatus;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.exception.DuplicatedSeatPositionException;
import com.ssafy.timo.domain.seat.exception.SeatErrorCode;
import com.ssafy.timo.domain.seat.exception.SeatPositionOutOfBoundsException;
import com.ssafy.timo.domain.seat.exception.SectionNameDuplicatedException;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import org.assertj.core.groups.Tuple;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicLong;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;

@ExtendWith(MockitoExtension.class)
class SeatServiceImplTest {

    private static final Long VENUE_ID = 10L;

    @Mock
    private SectionRepository sectionRepository;

    @Mock
    private SeatRepository seatRepository;

    @Mock
    private VenueRepository venueRepository;

    @InjectMocks
    private SeatServiceImpl seatService;

    @Captor
    private ArgumentCaptor<List<Seat>> seatsCaptor;

    @Test
    @DisplayName("구역을 등록하면 구역별 좌석 수와 전체 좌석 수가 담긴 응답이 반환된다")
    void register_success() {
        // given
        givenVenueExists();
        givenSectionSavedWithId();

        CommandSeatRequestDto request = request(
                layout("1층 A블록", 150_000,
                        seat(1, 1), seat(1, 2), seat(1, 3), seat(2, 1), seat(2, 3)),
                layout("2층 B블록", 90_000,
                        seat(1, 1), seat(1, 2)));

        // when
        CommandSeatResponseDto response = seatService.register(request);

        // then
        assertThat(response.venueId()).isEqualTo(VENUE_ID);
        assertThat(response.venueName()).isEqualTo("고척돔");
        assertThat(response.totalSeatCount()).isEqualTo(7);
        assertThat(response.sections())
                .extracting(
                        CommandSeatResponseDto.SectionSummary::name,
                        CommandSeatResponseDto.SectionSummary::price,
                        CommandSeatResponseDto.SectionSummary::seatCount)
                .containsExactly(
                        Tuple.tuple("1층 A블록", 150_000, 5),
                        Tuple.tuple("2층 B블록", 90_000, 2));
    }

    @Test
    @DisplayName("보낸 자리만 좌석이 되고 격자의 빈자리는 채우지 않는다")
    void register_createsOnlyListedSeats() {
        // given
        givenVenueExists();
        givenSectionSavedWithId();

        // 2행은 통로 때문에 2번 자리가 비어 있는 배치
        CommandSeatRequestDto request = request(layout("1층 A블록", 150_000,
                seat(1, 1), seat(1, 2), seat(1, 3),
                seat(2, 1), seat(2, 3)));

        // when
        seatService.register(request);

        // then
        then(seatRepository).should().saveAll(seatsCaptor.capture());

        assertThat(seatsCaptor.getValue())
                .extracting(Seat::getSeatNo, Seat::getSeatCol)
                .containsExactly(
                        Tuple.tuple(1, 1), Tuple.tuple(1, 2), Tuple.tuple(1, 3),
                        Tuple.tuple(2, 1), Tuple.tuple(2, 3));
    }

    @Test
    @DisplayName("구역의 좌석 수는 격자 크기가 아니라 실제로 만들어진 좌석 개수다")
    void register_fillsSeatCountFromCreatedSeats() {
        // given
        givenVenueExists();
        givenSectionSavedWithId();

        ArgumentCaptor<Section> sectionCaptor = ArgumentCaptor.forClass(Section.class);

        CommandSeatRequestDto request = request(layout("1층 A블록", 150_000,
                seat(1, 1), seat(1, 2), seat(2, 1), seat(2, 3), seat(3, 7)));

        // when
        CommandSeatResponseDto response = seatService.register(request);

        // then
        then(sectionRepository).should().save(sectionCaptor.capture());
        then(seatRepository).should().saveAll(seatsCaptor.capture());

        assertThat(sectionCaptor.getValue().getSeatCount())
                .isEqualTo(seatsCaptor.getValue().size())
                .isEqualTo(5);
        assertThat(response.totalSeatCount()).isEqualTo(5);
    }

    @Test
    @DisplayName("배치도 격자 크기를 보내지 않으면 나열된 좌석의 최대 번호에서 뽑아낸다")
    void register_derivesGridSizeFromListedSeats() {
        // given
        givenVenueExists();
        givenSectionSavedWithId();

        CommandSeatRequestDto request = request(layout("1층 A블록", 150_000,
                seat(1, 1), seat(2, 3), seat(4, 2)));

        // when
        CommandSeatResponseDto response = seatService.register(request);

        // then
        assertThat(response.sections()).singleElement()
                .extracting(
                        CommandSeatResponseDto.SectionSummary::rowCount,
                        CommandSeatResponseDto.SectionSummary::seatPerRow,
                        CommandSeatResponseDto.SectionSummary::seatCount)
                .containsExactly(4, 3, 3);
    }

    @Test
    @DisplayName("배치도 격자 크기를 함께 보내면 유도값으로 덮이지 않는다")
    void register_keepsDeclaredGridSize() {
        // given
        givenVenueExists();
        givenSectionSavedWithId();

        CommandSeatRequestDto request = request(layout("1층 A블록", 150_000, 10, 20,
                seat(1, 1), seat(2, 3)));

        // when
        CommandSeatResponseDto response = seatService.register(request);

        // then
        assertThat(response.sections()).singleElement()
                .extracting(
                        CommandSeatResponseDto.SectionSummary::rowCount,
                        CommandSeatResponseDto.SectionSummary::seatPerRow,
                        CommandSeatResponseDto.SectionSummary::seatCount)
                .containsExactly(10, 20, 2);
    }

    @Test
    @DisplayName("갓 등록된 좌석은 모두 예매 가능 상태이고 자신의 구역을 가리킨다")
    void register_createsAvailableSeatsBoundToSection() {
        // given
        givenVenueExists();
        givenSectionSavedWithId();

        CommandSeatRequestDto request = request(layout("1층 A블록", 150_000,
                seat(1, 1), seat(1, 2), seat(2, 1)));

        // when
        seatService.register(request);

        // then
        then(seatRepository).should().saveAll(seatsCaptor.capture());

        List<Seat> seats = seatsCaptor.getValue();
        assertThat(seats).hasSize(3);
        assertThat(seats).allSatisfy(seat -> {
            assertThat(seat.getStatus()).isEqualTo(SeatStatus.AVAILABLE);
            assertThat(seat.getSection().getName()).isEqualTo("1층 A블록");
        });
    }

    @Test
    @DisplayName("등급 구분이 없어 등록된 구역은 모두 일반석이다")
    void register_assignsCommonGrade() {
        // given
        givenVenueExists();
        givenSectionSavedWithId();

        // when
        CommandSeatResponseDto response = seatService.register(
                request(layout("1층 A블록", 150_000, seat(1, 1))));

        // then
        assertThat(response.sections()).singleElement()
                .extracting(CommandSeatResponseDto.SectionSummary::grade)
                .isEqualTo(SeatGrade.COMMON);
    }

    @Test
    @DisplayName("같은 자리가 두 번 들어오면 유니크 제약에 걸리기 전에 중복으로 걸러진다")
    void register_rejectsDuplicatedSeatPosition() {
        // given
        givenVenueExists();

        CommandSeatRequestDto request = request(layout("1층 A블록", 150_000,
                seat(1, 1), seat(1, 2), seat(1, 1)));

        // when & then
        assertThatThrownBy(() -> seatService.register(request))
                .isInstanceOf(DuplicatedSeatPositionException.class)
                .hasMessageContaining("seatNo=1")
                .hasMessageContaining("seatCol=1")
                .extracting(e -> ((DuplicatedSeatPositionException) e).getErrorCode())
                .isEqualTo(SeatErrorCode.DUPLICATED_SEAT_POSITION);

        then(sectionRepository).should(never()).save(any(Section.class));
        then(seatRepository).should(never()).saveAll(anyList());
    }

    @Test
    @DisplayName("선언한 격자 크기를 벗어난 자리가 있으면 범위 예외를 던진다")
    void register_rejectsSeatOutOfDeclaredBounds() {
        // given
        givenVenueExists();

        CommandSeatRequestDto request = request(layout("1층 A블록", 150_000, 2, 3,
                seat(1, 1), seat(3, 1)));

        // when & then
        assertThatThrownBy(() -> seatService.register(request))
                .isInstanceOf(SeatPositionOutOfBoundsException.class)
                .hasMessageContaining("seatNo=3")
                .hasMessageContaining("rowCount=2")
                .extracting(e -> ((SeatPositionOutOfBoundsException) e).getErrorCode())
                .isEqualTo(SeatErrorCode.SEAT_POSITION_OUT_OF_BOUNDS);

        then(sectionRepository).should(never()).save(any(Section.class));
        then(seatRepository).should(never()).saveAll(anyList());
    }

    @Test
    @DisplayName("존재하지 않는 공연장이면 구역도 좌석도 저장하지 않는다")
    void register_rejectsUnknownVenue() {
        // given
        given(venueRepository.findById(VENUE_ID)).willReturn(Optional.empty());

        CommandSeatRequestDto request = request(layout("1층 A블록", 150_000, seat(1, 1)));

        // when & then
        assertThatThrownBy(() -> seatService.register(request))
                .isInstanceOf(VenueNotFoundException.class)
                .hasMessageContaining("10");

        then(sectionRepository).should(never()).save(any(Section.class));
        then(seatRepository).should(never()).saveAll(anyList());
    }

    @Test
    @DisplayName("이미 등록된 구역명이면 중복 예외를 던지고 아무것도 저장하지 않는다")
    void register_rejectsNameAlreadyRegistered() {
        // given
        givenVenueExists();
        given(sectionRepository.existsByVenueIdAndName(VENUE_ID, "1층 A블록")).willReturn(true);

        CommandSeatRequestDto request = request(layout("1층 A블록", 150_000, seat(1, 1)));

        // when & then
        assertThatThrownBy(() -> seatService.register(request))
                .isInstanceOf(SectionNameDuplicatedException.class)
                .hasMessageContaining("1층 A블록")
                .extracting(e -> ((SectionNameDuplicatedException) e).getErrorCode())
                .isEqualTo(SeatErrorCode.SECTION_NAME_DUPLICATED);

        then(sectionRepository).should(never()).save(any(Section.class));
        then(seatRepository).should(never()).saveAll(anyList());
    }

    @Test
    @DisplayName("한 요청 안에 같은 구역명이 두 번 들어오면 유니크 제약에 걸리기 전에 중복으로 걸러진다")
    void register_rejectsDuplicatedNameWithinRequest() {
        // given
        givenVenueExists();
        given(sectionRepository.existsByVenueIdAndName(VENUE_ID, "1층 A블록")).willReturn(false);

        CommandSeatRequestDto request = request(
                layout("1층 A블록", 150_000, seat(1, 1)),
                layout("1층 A블록", 90_000, seat(1, 1)));

        // when & then
        assertThatThrownBy(() -> seatService.register(request))
                .isInstanceOf(SectionNameDuplicatedException.class)
                .hasMessageContaining("1층 A블록");

        then(sectionRepository).should(never()).save(any(Section.class));
        then(seatRepository).should(never()).saveAll(anyList());
    }

    private void givenVenueExists() {
        given(venueRepository.findById(VENUE_ID)).willReturn(Optional.of(venue()));
    }

    /** 좌석 생성이 저장 이후의 구역을 쓰므로, 저장 시 식별자가 채워지는 것까지 재현한다. */
    private void givenSectionSavedWithId() {
        AtomicLong sequence = new AtomicLong(1L);
        given(sectionRepository.save(any(Section.class))).willAnswer(invocation -> {
            Section section = invocation.getArgument(0);
            ReflectionTestUtils.setField(section, "id", sequence.getAndIncrement());
            return section;
        });
    }

    private CommandSeatRequestDto request(CommandSeatRequestDto.SectionLayout... sections) {
        return new CommandSeatRequestDto(VENUE_ID, List.of(sections));
    }

    /** 배치도 격자 크기는 서버가 뽑아내도록 비워 둔 구역. */
    private CommandSeatRequestDto.SectionLayout layout(String name,
                                                       int price,
                                                       CommandSeatRequestDto.SeatPositionRequest... seats) {
        return new CommandSeatRequestDto.SectionLayout(name, price, null, null, List.of(seats));
    }

    /** 배치도 격자 크기까지 직접 보내는 구역. */
    private CommandSeatRequestDto.SectionLayout layout(String name,
                                                       int price,
                                                       Integer rowCount,
                                                       Integer seatPerRow,
                                                       CommandSeatRequestDto.SeatPositionRequest... seats) {
        return new CommandSeatRequestDto.SectionLayout(name, price, rowCount, seatPerRow, List.of(seats));
    }

    private CommandSeatRequestDto.SeatPositionRequest seat(int seatNo, int seatCol) {
        return new CommandSeatRequestDto.SeatPositionRequest(seatNo, seatCol);
    }

    /** Venue 는 식별자를 직접 주입할 수 없으므로, 저장 이후 상태를 재현하기 위해 id 를 리플렉션으로 채운다. */
    private Venue venue() {
        Venue venue = Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16_000)
                .build();
        ReflectionTestUtils.setField(venue, "id", VENUE_ID);
        return venue;
    }
}
