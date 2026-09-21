package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.concert.service.ConcertService;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto.SectionSummary;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatStatus;
import com.ssafy.timo.domain.seat.repository.SeatHoldRepository;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
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
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

import com.ssafy.timo.domain.reservation.exception.BookingNotOpenException;

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

    /** 좌석 상태가 들어가는 공연. 예매 중인 것만이다. */
    private static final int EXPECTED_ON_SALE_CONCERTS = 3;

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
    private SectionRepository sectionRepository;

    @Autowired
    private ArtistRepository artistRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private LoginInfoRepository loginInfoRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private TicketRepository ticketRepository;

    @Autowired
    private com.ssafy.timo.domain.transfer.repository.TicketListingRepository ticketListingRepository;

    @Autowired
    private com.ssafy.timo.domain.blockchain.TicketNftClient ticketNftClient;

    @Autowired
    private com.ssafy.timo.domain.transfer.service.PurchaseService purchaseService;

    @Autowired
    private SeatHoldRepository seatHoldRepository;

    @Autowired
    private EntityManager em;

    @Autowired
    private Clock clock;

    @Autowired
    private com.ssafy.timo.domain.blockchain.ShowRegistryClient showRegistryClient;

    @Autowired
    private com.ssafy.timo.domain.wallet.service.WalletService walletService;

    @Autowired
    private com.ssafy.timo.global.config.blockchain.BlockchainProperties blockchainProperties;

    @Autowired
    private com.ssafy.timo.global.storage.ImageStorage imageStorage;

    @Autowired
    private org.springframework.core.env.Environment environment;

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

        // 구역 조회는 공연 기준이다. 시드 공연 중 이 공연장에서 열리는 것 하나를 고른다.
        Long seedConcertId = concertRepository.findAll().stream()
                .filter(c -> c.getVenue().getId().equals(venue.getId()))
                .findFirst()
                .orElseThrow()
                .getId();
        SectionListResponseDto sections = seatService.findSections(seedConcertId);
        assertThat(sections.sections()).hasSize(EXPECTED_SECTIONS);
        assertThat(sections.totalSeatCount()).isEqualTo(EXPECTED_TOTAL_SEATS);
        assertThat(sections.sections())
                .allSatisfy(section -> {
                    assertThat(section.seatCount()).isEqualTo(EXPECTED_SEATS_PER_SECTION);
                    assertThat(section.rowCount()).isEqualTo(10);
                });
        assertThat(sections.sections())
                .extracting(SectionSummary::name)
                .containsExactly("A구역", "B구역", "C구역", "2층 D구역", "2층 E구역");
        assertThat(sections.sections())
                .extracting(SectionSummary::price)
                .containsExactly(150_000, 150_000, 120_000, 120_000, 99_000);
        // 사다리꼴 배치라 구역마다 격자 폭(가장 넓은 열)이 다르다 - A·B·D·E는 25, 뒤쪽 C는 22.
        assertThat(sections.sections())
                .extracting(SectionSummary::seatPerRow)
                .containsExactly(25, 25, 22, 25, 25);
    }

    @Test
    @DisplayName("구역마다 9의 배수 자리는 판매 완료, 13의 배수 자리는 선점 중으로 들어간다")
    void seedsSoldAndHeldSeatsPerSection() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        Long concertId = onSaleConcertIds().get(0);
        Long sectionId = firstSectionId(concertId);

        SectionSeatListResponseDto seats = seatService.findSeats(concertId, sectionId);

        assertThat(seats.seats()).hasSize(EXPECTED_SEATS_PER_SECTION);
        assertThat(seats.seats()).filteredOn(seat -> seat.status() == SeatStatus.SOLD)
                .hasSize(EXPECTED_OCCUPIED_PER_SECTION);
        assertThat(seats.seats()).filteredOn(seat -> seat.status() == SeatStatus.HELD)
                .hasSize(EXPECTED_RESERVED_PER_SECTION);
        assertThat(seats.availableCount()).isEqualTo(EXPECTED_AVAILABLE_PER_SECTION);

        // 배치도 순서로 9번째는 판매, 13번째는 선점이다. 주기가 실제로 자리 번호를 따르는지 본다.
        assertThat(seats.seats().get(8).status()).isEqualTo(SeatStatus.SOLD);
        assertThat(seats.seats().get(12).status()).isEqualTo(SeatStatus.HELD);
    }

    @Test
    @DisplayName("시드 회원은 seed001 형식의 아이디로 로그인할 수 있다")
    void seedMembersCanSignIn() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        long soldPerConcert = (long) EXPECTED_OCCUPIED_PER_SECTION * EXPECTED_SECTIONS;
        long heldPerConcert = (long) EXPECTED_RESERVED_PER_SECTION * EXPECTED_SECTIONS;
        assertThat(loginInfoRepository.count()).isEqualTo(soldPerConcert + heldPerConcert);

        // seed001 은 시드가 만든 선점과 주문을 둘 다 가진 계정이다.
        LoginInfo first = loginInfoRepository.findByUsernameWithMember("seed001").orElseThrow();
        assertThat(first.getMember().getNickname()).isEqualTo("시드1");
        assertThat(passwordEncoder.matches("timo1234!", first.getPasswordHash()))
                .as("시드 비밀번호로 로그인할 수 있어야 한다")
                .isTrue();
    }

    @Test
    @DisplayName("시드 선점은 5분이 아니라 하루 뒤에 만료된다")
    void seedHoldsOutliveTheFiveMinuteRule() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        // 규약대로 5분이면 기동 5분 뒤에 선점 자리가 전부 예매 가능으로 보여 화면에서 확인할 수 없다.
        LocalDateTime fiveMinutesLater = LocalDateTime.now(clock).plusMinutes(5);
        assertThat(seatHoldRepository.findAll())
                .isNotEmpty()
                .allSatisfy(hold -> assertThat(hold.getExpiresAt()).isAfter(fiveMinutesLater));
    }

    @Test
    @DisplayName("시드 예매마다 발행 완료된 티켓이 한 장씩 생긴다 - 없으면 상세 조회도 양도 등록도 막힌다")
    void seedsOneMintedTicketPerReservation() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        List<Ticket> tickets = ticketRepository.findAll();

        // 주문 하나에 티켓 하나다(uk_ticket_reservation).
        assertThat(tickets).hasSize((int) reservationRepository.count());

        // OWNED 여야 한다. PENDING_MINT 면 ListingService 가 "발행 전 티켓" 으로 거절해
        // 로컬에서 양도 등록을 만져 볼 수 없다. 시드가 매물로 연 티켓만 LISTED 다.
        assertThat(tickets).allSatisfy(ticket ->
                assertThat(ticket.getStatus()).isIn(TicketStatus.OWNED, TicketStatus.LISTED));

        // tokenId 는 uk_ticket_token_id 가 걸려 있어 주문마다 달라야 한다.
        assertThat(tickets).extracting(Ticket::getTokenId).doesNotContainNull().doesNotHaveDuplicates();
        // 해시 컬럼이 66자(0x + 64)라 형식이 어긋나면 저장 단계에서 잘린다.
        assertThat(tickets).allSatisfy(ticket ->
                assertThat(ticket.getMintTxHash()).hasSize(66).startsWith("0x"));
    }

    @Test
    @DisplayName("예매 중인 공연마다 양도 매물이 열리고, 어제 등록이라 당일에 바로 보인다")
    void seedsTransferListings() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        List<com.ssafy.timo.domain.transfer.entity.TicketListing> listings = ticketListingRepository.findAll();

        // 예매 중인 공연 2건 x 공연당 2건.
        assertThat(listings).hasSize(EXPECTED_ON_SALE_CONCERTS * 2);
        assertThat(listings).allSatisfy(listing -> {
            assertThat(listing.getStatus())
                    .isEqualTo(com.ssafy.timo.domain.transfer.entity.ListingStatus.LISTED);
            // 등록 다음 날부터 보이므로 어제여야 기동 당일에 목록과 구매가 열린다.
            assertThat(listing.getListedAt()).isBefore(LocalDateTime.now(clock).toLocalDate().atStartOfDay());
            // 정가 초과 판매 차단이 이 서비스의 존재 이유다. 시드가 그 규칙을 깨면 안 된다.
            assertThat(listing.getPrice()).isLessThanOrEqualTo(listing.getFaceValue());
            // 매물이 열린 티켓은 LISTED 여야 판매자가 먼저 입장하는 이중 입장이 막힌다.
            assertThat(ticketRepository.findById(listing.getTicketId()).orElseThrow().getStatus())
                    .isEqualTo(TicketStatus.LISTED);
        });
    }

    @Test
    @DisplayName("시드 매물을 사면 소유자가 구매자로 넘어가고 매물이 닫힌다")
    void seededListingCanBePurchased() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        com.ssafy.timo.domain.transfer.entity.TicketListing listing = ticketListingRepository.findAll().getFirst();
        Long ticketId = listing.getTicketId();
        com.ssafy.timo.domain.member.entity.Member buyer = memberRepository.save(
                com.ssafy.timo.domain.member.entity.Member.builder()
                        .phoneNumber("01055556666").name("구매자").nickname("시드구매자").build());
        flushAndClear();

        purchaseService.purchase(listing.getId(),
                new com.ssafy.timo.domain.transfer.dto.PurchaseRequestDto(listing.getPrice()), buyer.getId());
        flushAndClear();

        Ticket sold = ticketRepository.findById(ticketId).orElseThrow();
        assertThat(sold.getOwnerMemberId()).isEqualTo(buyer.getId());
        assertThat(sold.getStatus()).isEqualTo(TicketStatus.OWNED);
        assertThat(ticketListingRepository.findById(listing.getId()).orElseThrow().getStatus())
                .isEqualTo(com.ssafy.timo.domain.transfer.entity.ListingStatus.SOLD);
    }

    @Test
    @DisplayName("좌석 상태는 예매 중인 공연에만 들어가고, 시드 회원은 공연마다 재사용된다")
    void seedsOnlyOnSaleConcertsAndReusesMembers() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        List<Concert> concerts = concertRepository.findAll();
        assertThat(concerts).hasSize(5);

        for (Concert concert : concerts) {
            if (concert.getStatus() == ConcertStatus.SCHEDULED) {
                // 오픈 전 공연은 구역·좌석 조회가 막힌다.
                assertThatThrownBy(() -> seatService.findSections(concert.getId()))
                        .as("오픈 전 %s 의 구역 조회", concert.getTitle())
                        .isInstanceOf(BookingNotOpenException.class);
                continue;
            }
            Long sectionId = firstSectionId(concert.getId());
            int available = seatService.findSeats(concert.getId(), sectionId).availableCount();

            if (concert.getStatus() == ConcertStatus.ON_SALE) {
                assertThat(available).as("예매 중인 %s 의 잔여석", concert.getTitle())
                        .isEqualTo(EXPECTED_AVAILABLE_PER_SECTION);
            } else {
                // 오픈 전이거나 끝난 공연은 아무도 잡지 않았다. 상태와 배치도가 어긋나면 안 된다.
                assertThat(available).as("예매 중이 아닌 %s 의 잔여석", concert.getTitle())
                        .isEqualTo(EXPECTED_SEATS_PER_SECTION);
            }
        }

        // 유니크가 (concert_id, member) 라 공연이 다르면 같은 회원을 다시 쓸 수 있다. 그래서 필요한
        // 회원 수는 전체 좌석 수가 아니라 공연 하나에서 필요한 수(판매+선점)다. 다만 판매자와
        // 선점자는 같은 공연 안에서 겹치면 안 된다 — 겹치면 이미 표를 산 회원이 같은 공연에서 또
        // 선점하는 꼴이라 "1인 1매" 에 걸린다.
        long soldPerConcert = (long) EXPECTED_OCCUPIED_PER_SECTION * EXPECTED_SECTIONS;
        long heldPerConcert = (long) EXPECTED_RESERVED_PER_SECTION * EXPECTED_SECTIONS;
        assertThat(memberRepository.count()).isEqualTo(soldPerConcert + heldPerConcert);
        assertThat(reservationRepository.count())
                .isEqualTo(soldPerConcert * EXPECTED_ON_SALE_CONCERTS);
        assertThat(seatHoldRepository.count())
                .isEqualTo(heldPerConcert * EXPECTED_ON_SALE_CONCERTS);
    }


    @Test
    @DisplayName("공연 5건을 상태·조회수·이미지까지 시드대로 넣는다")
    void seedsFourConcertsWithTheirStateAndImages() {
        seeder.run(new DefaultApplicationArguments());
        flushAndClear();

        Map<String, Concert> concerts = concertRepository.findAll().stream()
                .collect(Collectors.toMap(Concert::getTitle, Function.identity()));

        assertThat(concerts).hasSize(5);

        assertThat(concerts.get("김필 단독 콘서트"))
                .satisfies(concert -> {
                    assertThat(concert.getStatus()).isEqualTo(ConcertStatus.CLOSED);
                    assertThat(concert.getViewCount()).isEqualTo(1_203);
                    assertThat(concert.getPosterImageKey()).isEqualTo("poster/poster_main_kim_feel.gif");
                });
        assertThat(concerts.get("이승기 콘서트").getStatus()).isEqualTo(ConcertStatus.SCHEDULED);
        assertThat(concerts.get("로이킴 콘서트").getStatus()).isEqualTo(ConcertStatus.ON_SALE);
        assertThat(concerts.get("Bruno Mars 내한공연").getStatus()).isEqualTo(ConcertStatus.ON_SALE);

        // 상태와 날짜가 서로 맞아야 한다. 어긋나면 오픈이 남은 공연이 예매 중이거나
        // 이미 끝난 공연을 예매할 수 있는 데이터가 된다.
        //
        // 공연일이 미래인 것만으로는 부족하다. 선점·결제는 startDate - BOOKING_CUTOFF_HOURS 부터
        // 마감으로 거절되므로, 공연일이 지금부터 한 시간 뒤라면 이 단정은 통과하는데 로컬에서는
        // 예매가 이미 막혀 있다. 시드 날짜가 낡은 것을 알려주는 장치가 이것뿐이라, 마감 시각까지
        // 여유가 남았는지를 본다. 로컬에서 예매 흐름을 볼 수 있어야 한다는 것이 이 시드의 목적이다.
        LocalDateTime now = LocalDateTime.now(clock);
        assertThat(concerts.values())
                .filteredOn(concert -> concert.getStatus() == ConcertStatus.ON_SALE)
                .hasSize(EXPECTED_ON_SALE_CONCERTS)
                .allSatisfy(concert -> {
                    assertThat(concert.getOpenAt()).as("%s 오픈", concert.getTitle()).isBefore(now);
                    assertThat(concert.getStartDate()).as("%s 예매 마감", concert.getTitle())
                            .isAfter(now.plusHours(Concert.BOOKING_CUTOFF_HOURS));
                });
        assertThat(concerts.get("이승기 콘서트").getOpenAt()).isAfter(now);
        assertThat(concerts.get("김필 단독 콘서트").getEndDate()).isBefore(now);

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

        assertThat(concertRepository.count()).isEqualTo(5);
        assertThat(seatRepository.count()).isEqualTo(seatsAfterFirstRun);
        assertThat(venueRepository.findAll())
                .filteredOn(venue -> venue.getName().equals("고척돔"))
                .hasSize(1);
    }

    @Test
    @DisplayName("local · demo 프로필이 아니면 빈으로 등록되지 않는다")
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
                sectionRepository,
                artistRepository,
                memberRepository,
                loginInfoRepository,
                reservationRepository,
                ticketRepository,
                ticketListingRepository,
                ticketNftClient,
                passwordEncoder,
                em,
                clock,
                showRegistryClient,
                walletService,
                blockchainProperties,
                imageStorage,
                environment);
    }

    /** 좌석 상태가 들어간 공연들. 예매 중인 것만이라 상태로 고른다. */
    private List<Long> onSaleConcertIds() {
        return concertRepository.findAll().stream()
                .filter(concert -> concert.getStatus() == ConcertStatus.ON_SALE)
                .map(Concert::getId)
                .toList();
    }

    private Long firstSectionId(Long concertId) {
        return seatService.findSections(concertId).sections().stream()
                .findFirst().orElseThrow().id();
    }

    /** 시더가 상태·조회수를 벌크 갱신으로 넣으므로, 영속성 컨텍스트를 비우고 DB 에서 다시 읽는다. */
    private void flushAndClear() {
        em.flush();
        em.clear();
    }

    private static Artist artist(String name, String profileImage) {
        return Artist.builder().name(name).profileImageKey(profileImage).build();
    }
}
