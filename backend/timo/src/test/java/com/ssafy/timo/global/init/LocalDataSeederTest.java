package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.concert.service.ConcertService;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto.SectionSummary;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatStatus;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.service.SeatService;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.domain.venue.service.VenueService;
import com.ssafy.timo.support.IntegrationTest;

import jakarta.persistence.EntityManager;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.DefaultApplicationArguments;
import org.springframework.context.ApplicationContext;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * 로컬 시더 통합 테스트.
 *
 * <p>시더는 {@code @Profile("local")} 이라 이 컨텍스트({@code test} 프로필)에 빈으로 뜨지 않는다.
 * 그래서 <b>직접 생성해서</b> {@code run} 을 부른다. 프로필을 추가하거나 {@code @TestPropertySource}
 * 로 설정을 덮으면 컨텍스트가 하나 더 떠서 {@link IntegrationTest} 의 단일 컨텍스트 규약을 깨고,
 * {@code create-drop} 인 같은 스키마를 두 컨텍스트가 서로 drop 하게 된다.
 *
 * <p>기동 시 실제로 불리는지(= {@link org.springframework.boot.ApplicationRunner} 계약)는 여기서
 * 검증하지 않는다. 이 테스트가 보는 것은 "불렸을 때 어떤 데이터가 만들어지는가" 다.
 *
 * <p>아티스트는 로컬에서 {@code db/seed-local.sql} 이 넣지만 {@code test} 프로필은 그 SQL 을 타지
 * 않으므로 여기서 직접 만든다. id 는 자동 생성에 맡긴다 — 시더가 이름으로 찾으므로 값이 무엇이든 된다.
 */
@IntegrationTest
class LocalDataSeederTest {

    private static final int EXPECTED_SECTIONS = 5;
    private static final int EXPECTED_SEATS_PER_SECTION = 200;
    private static final int EXPECTED_TOTAL_SEATS = EXPECTED_SECTIONS * EXPECTED_SEATS_PER_SECTION;

    /** 구역당 자리 번호 9의 배수 22개, 13의 배수 15개 중 겹치는 117번째를 뺀 14개. */
    private static final int EXPECTED_OCCUPIED_PER_SECTION = 22;
    private static final int EXPECTED_RESERVED_PER_SECTION = 14;
    private static final int EXPECTED_AVAILABLE_PER_SECTION =
            EXPECTED_SEATS_PER_SECTION - EXPECTED_OCCUPIED_PER_SECTION - EXPECTED_RESERVED_PER_SECTION;

    @Autowired
    private ApplicationContext applicationContext;

    @Autowired
    private ConcertService concertService;

    @Autowired
    private SeatService seatService;

    @Autowired
    private VenueService venueService;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private ArtistRepository artistRepository;

    @Autowired
    private EntityManager em;

    @Autowired
    private Clock clock;

    private LocalDataSeeder seeder;

    @BeforeEach
    void setUp() {
        artistRepository.saveAll(List.of(
                artist("김필", "artist/artist_kim_feel.jpg"),
                artist("이승기", "artist/artist_lee_s.jpg"),
                artist("로이킴", "artist/artist_roykim.jpg"),
                artist("Bruno Mars", "artist/artist_bruno_mars.jpg")));

        seeder = newSeeder();
    }

    @Test
    @DisplayName("공연장 하나와 5구역 1,000석을 넣는다")
    void seedsVenueWithFiveSectionsOfTwoHundredSeats() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        Venue venue = venueRepository.findByName("고척돔").orElseThrow();
        assertThat(venue.getTotalSeatCount()).isEqualTo(EXPECTED_TOTAL_SEATS);

        SectionListResponseDto sections = seatService.findSections(venue.getId());
        assertThat(sections.sections()).hasSize(EXPECTED_SECTIONS);
        assertThat(sections.totalSeatCount()).isEqualTo(EXPECTED_TOTAL_SEATS);
        assertThat(sections.sections())
                .allSatisfy(section -> {
                    assertThat(section.seatCount()).isEqualTo(EXPECTED_SEATS_PER_SECTION);
                    assertThat(section.rowCount()).isEqualTo(10);
                    assertThat(section.seatPerRow()).isEqualTo(20);
                });
        assertThat(sections.sections())
                .extracting(SectionSummary::name)
                .containsExactly("1층 A블록", "1층 B블록", "2층 C블록", "2층 D블록", "3층 E블록");
        assertThat(sections.sections())
                .extracting(SectionSummary::price)
                .containsExactly(150_000, 150_000, 120_000, 120_000, 99_000);
    }

    @Test
    @DisplayName("좌석 일부를 판매 완료·선점 중으로 섞어 잔여석이 총좌석보다 적다")
    void mixesTakenSeatsSoAvailableCountIsLowerThanTotal() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        Venue venue = venueRepository.findByName("고척돔").orElseThrow();
        SectionListResponseDto sections = seatService.findSections(venue.getId());

        assertThat(sections.totalAvailableCount())
                .isEqualTo(EXPECTED_AVAILABLE_PER_SECTION * EXPECTED_SECTIONS)
                .isLessThan(sections.totalSeatCount());
        assertThat(sections.sections())
                .extracting(SectionSummary::availableCount)
                .containsOnly(EXPECTED_AVAILABLE_PER_SECTION);

        Long sectionId = sections.sections().getFirst().id();
        Map<SeatStatus, Long> distribution = seatRepository
                .findAllBySectionIdOrderBySeatNoAscSeatColAsc(sectionId).stream()
                .collect(Collectors.groupingBy(Seat::getStatus, Collectors.counting()));

        assertThat(distribution).containsOnly(
                Map.entry(SeatStatus.OCCUPIED, (long) EXPECTED_OCCUPIED_PER_SECTION),
                Map.entry(SeatStatus.RESERVED, (long) EXPECTED_RESERVED_PER_SECTION),
                Map.entry(SeatStatus.AVAILABLE, (long) EXPECTED_AVAILABLE_PER_SECTION));
    }

    @Test
    @DisplayName("좌석 상태는 자리 번호로 정해진다 - 9의 배수는 판매 완료, 13의 배수는 선점")
    void seatStatusFollowsSeatIndexRule() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        Venue venue = venueRepository.findByName("고척돔").orElseThrow();
        Long sectionId = seatService.findSections(venue.getId()).sections().getFirst().id();

        List<Seat> seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(sectionId);
        assertThat(seats).hasSize(EXPECTED_SEATS_PER_SECTION);

        for (int i = 0; i < seats.size(); i++) {
            int seatIndex = i + 1;
            assertThat(seats.get(i).getStatus())
                    .as("%d번째 자리", seatIndex)
                    .isEqualTo(expectedStatusOf(seatIndex));
        }
    }

    @Test
    @DisplayName("선점 자리는 만료가 넉넉해 곧바로 예매 가능으로 돌아가지 않는다")
    void reservedSeatsDoNotExpireImmediately() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        Venue venue = venueRepository.findByName("고척돔").orElseThrow();
        Long sectionId = seatService.findSections(venue.getId()).sections().getFirst().id();

        List<Seat> reserved = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(sectionId).stream()
                .filter(seat -> seat.getStatus() == SeatStatus.RESERVED)
                .toList();

        LocalDateTime oneHourLater = LocalDateTime.now(clock).plusHours(1);
        assertThat(reserved)
                .isNotEmpty()
                .allSatisfy(seat -> assertThat(seat.effectiveStatus(oneHourLater))
                        .isEqualTo(SeatStatus.RESERVED));

        // 선점을 한 사람이 몰아 쥐면 "한 계정 동시 하나" 규칙에 어긋나는 데이터가 된다.
        assertThat(reserved).extracting(Seat::getHeldByMemberId).doesNotHaveDuplicates();
    }

    @Test
    @DisplayName("공연 4건을 상태·조회수·이미지까지 시드대로 넣는다")
    void seedsFourConcertsWithTheirStateAndImages() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        Map<String, Concert> concerts = concertRepository.findAll().stream()
                .collect(Collectors.toMap(Concert::getTitle, Function.identity()));

        assertThat(concerts).hasSize(4);

        assertThat(concerts.get("김필 단독 콘서트"))
                .satisfies(concert -> {
                    assertThat(concert.getStatus()).isEqualTo(ConcertStatus.ON_SALE);
                    assertThat(concert.getViewCount()).isEqualTo(1_203);
                    assertThat(concert.getPosterImageKey()).isEqualTo("poster/poster_main_kim_feel.gif");
                });
        assertThat(concerts.get("이승기 콘서트").getStatus()).isEqualTo(ConcertStatus.SCHEDULED);
        assertThat(concerts.get("로이킴 콘서트").getStatus()).isEqualTo(ConcertStatus.SOLD_OUT);
        assertThat(concerts.get("Bruno Mars 내한공연").getStatus()).isEqualTo(ConcertStatus.CLOSED);

        // 상세 이미지 원본이 없는 공연은 빈 목록이어야 한다.
        assertThat(concerts.get("로이킴 콘서트").getImages()).isEmpty();
        assertThat(concerts.get("김필 단독 콘서트").getImages())
                .extracting(image -> image.getImageKey())
                .containsExactly("detail/poster_detail_kim.jpg");
    }

    @Test
    @DisplayName("공연에 이름으로 찾은 아티스트가 붙는다")
    void attachesArtistsFoundByName() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        Concert concert = concertRepository.findAll().stream()
                .filter(it -> it.getTitle().equals("Bruno Mars 내한공연"))
                .findFirst()
                .orElseThrow();

        assertThat(concert.getArtists())
                .extracting(Artist::getName)
                .containsExactly("Bruno Mars");
    }

    @Test
    @DisplayName("시드 아티스트가 없으면 원인을 밝히며 실패한다")
    void failsLoudlyWhenSeedArtistIsMissing() {
        artistRepository.deleteAll();
        flushAndClear();

        assertThatThrownBy(() -> newSeeder().run(new DefaultApplicationArguments()))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("seed-local.sql")
                .hasMessageContaining("김필");
    }

    @Test
    @DisplayName("이미 공연이 있으면 아무것도 넣지 않는다")
    void skipsWhenConcertsAlreadyExist() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        long seatsAfterFirstRun = seatRepository.count();

        newSeeder().run(new DefaultApplicationArguments());
        flushAndClear();

        assertThat(concertRepository.count()).isEqualTo(4);
        assertThat(seatRepository.count()).isEqualTo(seatsAfterFirstRun);
        assertThat(venueRepository.findAll())
                .filteredOn(venue -> venue.getName().equals("고척돔"))
                .hasSize(1);
    }

    @Test
    @DisplayName("local 프로필이 아니면 빈으로 등록되지 않는다")
    void isNotRegisteredOutsideLocalProfile() {
        assertThat(applicationContext.getBeanNamesForType(LocalDataSeeder.class)).isEmpty();
    }

    private LocalDataSeeder newSeeder() {
        return new LocalDataSeeder(
                concertService,
                seatService,
                venueService,
                concertRepository,
                venueRepository,
                seatRepository,
                artistRepository,
                em,
                clock);
    }

    /** 시더가 상태·조회수를 벌크 갱신으로 넣으므로, 영속성 컨텍스트를 비우고 DB 에서 다시 읽는다. */
    private void flushAndClear() {
        em.flush();
        em.clear();
    }

    private static SeatStatus expectedStatusOf(int seatIndex) {
        if (seatIndex % 9 == 0) {
            return SeatStatus.OCCUPIED;
        }
        if (seatIndex % 13 == 0) {
            return SeatStatus.RESERVED;
        }
        return SeatStatus.AVAILABLE;
    }

    private static Artist artist(String name, String profileImage) {
        return Artist.builder().name(name).profileImage(profileImage).build();
    }
}
