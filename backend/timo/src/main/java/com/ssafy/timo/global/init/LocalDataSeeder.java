package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.concert.service.ConcertService;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto.SeatPositionRequest;
import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto.SectionLayout;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.seat.service.SeatService;
import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.domain.venue.service.VenueService;

import jakarta.persistence.EntityManager;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 로컬 기동 시 데모 데이터를 DB 에 채운다. 공연장 1곳 → 좌석 배치도 → 공연 4건 순이다.
 *
 * <p>시드 값은 이 클래스가 직접 들고 있다. 같은 데모 데이터를 v0 스텁도 갖고 있지만
 * ({@code com.ssafy.timo.stub.StubFixtures}) 거기서 가져오지 않는다. 스텁은 v1 이 갖춰지면 지울
 * 임시 코드라, 지우는 순간 이 시더가 함께 깨진다. 공연이 이 4건인 것은 스텁 때문이 아니라
 * {@code src/main/resources/static} 에 있는 포스터·프로필 이미지와 {@code db/seed-local.sql} 이
 * 넣는 아티스트가 그 4명이기 때문이다.
 *
 * <p>아티스트는 등록 API 가 없어 {@code db/seed-local.sql} 이 넣고, 여기서는 <b>이름으로 찾아</b> 쓴다.
 * id 를 박아 두지 않는 이유는, 그 SQL 의 순서나 id 가 바뀌어도 조용히 엉뚱한 아티스트가 붙지 않게
 * 하기 위해서다. 이름이 하나라도 없으면 그 자리에서 실패한다.
 *
 * <p>모든 데이터는 실제 등록 서비스({@link VenueService}·{@link SeatService}·{@link ConcertService})를
 * 거친다. 리포지토리에 직접 넣으면 등록 경로가 하는 검증을 건너뛰어, 시드로는 들어가지만 API 로는
 * 만들 수 없는 데이터가 생길 수 있다.
 *
 * <p>{@code @PostConstruct} 가 아니라 {@link ApplicationRunner} 인 이유가 두 가지다. 하나는
 * {@code seed-local.sql} 이 데이터소스 초기화 시점에 돌아 빈 생성 시점과 선후가 보장되지 않는 것이고,
 * 다른 하나는 {@code @PostConstruct} 가 프록시가 적용되기 전에 불려 {@code @Transactional} 이
 * 걸리지 않는 것이다. 컨텍스트가 다 뜬 뒤에 도는 러너에는 두 문제가 모두 없다.
 *
 * <p>{@code local} 프로필에서만 등록된다. 운영에서 이 빈이 뜨면 기동할 때마다 가짜 공연이 쌓인다.
 */
@Slf4j
@Component
@Profile("local")
@RequiredArgsConstructor
public class LocalDataSeeder implements ApplicationRunner {

    // ---- 공연장 ---------------------------------------------------------------------------------

    /**
     * 공연장명은 10자 제한이다.
     */
    private static final String VENUE_NAME = "고척돔";
    private static final String VENUE_ADDRESS = "서울시 구로구 경인로 430";

    // ---- 구역 · 좌석 ------------------------------------------------------------------------------

    /**
     * 시드 배치도의 격자. 구역마다 10행 20열이 빈자리 없이 들어찬다.
     */
    private static final int ROW_COUNT = 10;
    private static final int SEAT_PER_ROW = 20;

    /**
     * 구역 하나의 좌석 수. 통로를 두지 않아 격자 크기가 그대로 좌석 수다.
     */
    private static final int SEATS_PER_SECTION = ROW_COUNT * SEAT_PER_ROW;

    /**
     * 구역 하나의 시드 정보. 등급은 아직 구분이 없어 서버가 {@code COMMON} 으로 정한다.
     */
    private record SectionSeed(String name, int price) {
    }

    /**
     * 이미 팔렸거나 남이 잡고 있는 자리를 섞는 주기. 구역 안 자리 번호가 이 수의 배수면 그 상태가 된다.
     *
     * <p>두 조건이 겹치는 자리(117번째)는 점유가 이긴다. v0 스텁이 쓰는 규칙과 같은 값이지만
     * 스텁에서 가져오지는 않는다 — 같은 의도를 따로 구현한 것이다.
     */
    private static final int OCCUPIED_EVERY = 9;
    private static final int RESERVED_EVERY = 13;

    /**
     * 시드 회원의 전화번호·닉네임 접두. 개발자가 직접 가입해 만든 계정과 섞이지 않게 띄워 둔다.
     *
     * <p><b>실재하는 회원 행이 필요하다.</b> {@code seat_hold} · {@code reservation} 모두
     * {@code member_id} 를 NOT NULL 연관관계로 들고 있어, 예전처럼 아무 숫자를 박아 넣을 수 없다.
     *
     * <p>{@code member} 는 전화번호와 닉네임에 유니크가 걸려 있다. 접두가 겹치면 기동이 그 자리에서
     * 실패하므로, 값을 바꿀 때는 두 가지 모두 확인한다.
     */
    private static final String SEED_MEMBER_PHONE_PREFIX = "0109900";
    private static final String SEED_MEMBER_NICKNAME_PREFIX = "시드";

    /**
     * 시드 회원의 로그인 정보. <b>로컬 전용이다.</b>
     *
     * <p>아이디는 {@code seed001} 부터, 비밀번호는 전원 같다. 가입 API 가 요구하는 형식
     * ({@code AuthPatterns.USERNAME} · {@code PASSWORD_SHAPE})에 맞춰 두어, 이 계정으로 로그인한
     * 뒤의 동작이 직접 가입한 계정과 갈리지 않게 한다.
     *
     * <p>{@code seed001} 이 시드가 만든 선점과 주문을 <b>둘 다</b> 갖는다. 좌석을 나눠 줄 때
     * 회원을 순서대로 쓰기 때문이다. "내가 잡은 자리" 화면을 볼 때 이 계정으로 들어가면 된다.
     */
    private static final String SEED_MEMBER_USERNAME_PREFIX = "seed";
    private static final String SEED_MEMBER_PASSWORD = "timo1234!";

    /**
     * 시드 선점의 유지 시간. 실제 규약(5분)과 무관하게 길게 잡는다.
     *
     * <p>5분으로 두면 기동 5분 뒤에 선점 자리가 전부 예매 가능으로 보여 화면에서 확인할 시간이 없다.
     */
    private static final Duration SEED_HOLD_DURATION = Duration.ofDays(1);

    /**
     * 시드 구역 5개. 층이 올라갈수록 가격을 낮춰 구역 선택 화면에서 가격대가 갈리는 것을 볼 수 있게 했다.
     */
    private static final List<SectionSeed> SECTION_SEEDS = List.of(
            new SectionSeed("A구역", 150_000),
            new SectionSeed("B구역", 150_000),
            new SectionSeed("C구역", 120_000),
            new SectionSeed("2층 D구역", 120_000),
            new SectionSeed("2층 E구역", 99_000));

    // ---- 공연 -----------------------------------------------------------------------------------

    /**
     * 공연 하나의 시드 정보.
     *
     * <p>이미지는 URL 이 아니라 저장소 key 다. 로컬은 {@code src/main/resources/static} 이 그대로
     * 정적 리소스로 서빙되므로, 여기 적은 key 가 곧 {@code /poster/...} 경로가 된다.
     *
     * <p>{@code status} · {@code viewCount} 는 등록 API 로는 정할 수 없는 값이다. 왜 여기서 들고
     * 있는지는 {@link #applySeedState} 참고.
     *
     * @param artistNames {@code db/seed-local.sql} 이 넣는 아티스트 이름
     */
    private record ConcertSeed(
            String title,
            ConcertGenre genre,
            String posterImageKey,
            List<String> imageKeys,
            String description,
            AgeRating ageRating,
            ConcertStatus status,
            int viewCount,
            LocalDateTime startDate,
            LocalDateTime endDate,
            LocalDateTime openAt,
            List<String> artistNames
    ) {
    }

    /**
     * 시드 공연 4건. {@code static/poster} 에 있는 포스터 하나에 공연 하나씩이다.
     *
     * <p>상태·장르·조회수가 골고루 갈리도록 골랐다. 그래야 목록의 상태 필터와 인기순 정렬을 눌러 볼 수
     * 있다. 로이킴 공연만 상세 이미지가 비어 있는데, {@code static/detail} 에 해당 파일이 없어서다 —
     * 상세 이미지가 없는 공연도 화면이 깨지지 않는지 확인하는 자리도 된다.
     *
     * <p><b>상태와 날짜를 서로 맞춰 둔다.</b> {@link ConcertStatus} 는 오픈 전 · 예매 중 · 종료를
     * 뜻하는데 날짜가 따로 놀면, 오픈이 한 달 남은 공연이 예매 중이거나 이미 끝난 공연을 예매할 수
     * 있는 데이터가 된다. 규칙은 이렇다.
     *
     * <ul>
     *   <li>{@code ON_SALE} — {@code openAt} 은 과거, {@code startDate} 는 미래</li>
     *   <li>{@code SCHEDULED} — {@code openAt} 도 {@code startDate} 도 미래</li>
     *   <li>{@code CLOSED} — 전부 과거</li>
     * </ul>
     *
     * <p>날짜를 고정값으로 박아 둔 탓에 <b>시간이 지나면 이 관계가 깨진다.</b> {@code ON_SALE} 공연의
     * {@code startDate} 가 지나면 "예매 중인데 이미 끝난 공연" 이 된다. 그때는 여기 날짜를 뒤로 민다.
     */
    private static final List<ConcertSeed> CONCERT_SEEDS = List.of(
            // 내역. 이미 끝난 공연이라 예매 화면이 아니라 지난 공연 목록에서 확인한다.
            new ConcertSeed("김필 단독 콘서트", ConcertGenre.CONCERT,
                    "poster/poster_main_kim_feel.gif",
                    List.of("detail/poster_detail_kim.jpg"),
                    "김필 단독 콘서트", AgeRating.AGE_7, ConcertStatus.CLOSED, 1_203,
                    LocalDateTime.of(2026, 7, 10, 19, 0), LocalDateTime.of(2026, 7, 10, 21, 0),
                    LocalDateTime.of(2026, 6, 1, 20, 0), List.of("김필")),
            // 대기. 오픈이 아직 남아 좌석 화면에 들어갈 수 없다.
            new ConcertSeed("이승기 콘서트", ConcertGenre.CONCERT,
                    "poster/poster_main_lee.gif",
                    List.of("detail/poster_detail_lee.jpg"),
                    "이승기 단독 콘서트", AgeRating.ALL, ConcertStatus.SCHEDULED, 512,
                    LocalDateTime.of(2026, 11, 21, 18, 0), LocalDateTime.of(2026, 11, 21, 21, 0),
                    LocalDateTime.of(2026, 10, 15, 20, 0), List.of("이승기")),
            // 예매 중. 좌석 상태가 들어가는 두 건 중 하나다.
            new ConcertSeed("로이킴 콘서트", ConcertGenre.CONCERT,
                    "poster/poster_main_roykim.jpg",
                    List.of(),
                    "로이킴 단독 콘서트", AgeRating.AGE_7, ConcertStatus.ON_SALE, 3_300,
                    LocalDateTime.of(2026, 9, 20, 19, 30), LocalDateTime.of(2026, 9, 20, 21, 30),
                    LocalDateTime.of(2026, 8, 1, 14, 0), List.of("로이킴")),
            // 예매 중. 좌석 상태가 들어가는 두 건 중 하나다.
            new ConcertSeed("Bruno Mars 내한공연", ConcertGenre.CONCERT,
                    "poster/poster_main_mars.gif",
                    List.of("detail/poster_detail_mars.jpg"),
                    "Bruno Mars 내한 단독 공연", AgeRating.ALL, ConcertStatus.ON_SALE, 87,
                    LocalDateTime.of(2026, 12, 5, 19, 0), LocalDateTime.of(2026, 12, 5, 21, 0),
                    LocalDateTime.of(2026, 9, 1, 20, 0), List.of("Bruno Mars")));

    private final ConcertService concertService;
    private final SeatService seatService;
    private final VenueService venueService;
    private final ConcertRepository concertRepository;
    private final VenueRepository venueRepository;
    private final SeatRepository seatRepository;
    private final SectionRepository sectionRepository;
    private final ArtistRepository artistRepository;
    private final MemberRepository memberRepository;
    private final LoginInfoRepository loginInfoRepository;
    private final ReservationRepository reservationRepository;
    private final PasswordEncoder passwordEncoder;
    private final EntityManager entityManager;
    private final Clock clock;

    /**
     * 공연이 하나라도 있으면 아무것도 하지 않는다.
     *
     * <p>로컬은 {@code ddl-auto: create-drop} 이라 보통 매 기동마다 비어 있지만, DB 를 남겨 두고 앱만
     * 재시작하는 경우에 같은 공연이 다시 쌓이는 것을 막는다.
     */
    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        long existing = concertRepository.count();
        if (existing > 0) {
            log.info("공연이 이미 {}건 있어 시드를 건너뛴다.", existing);
            return;
        }

        Long venueId = findOrRegisterVenue();
        seedSeats(venueId);

        Map<String, Long> artistIds = findArtistIdsByName();

        // 좌석 상태는 예매 중인 공연에만 넣는다. 오픈 전이거나 끝난 공연에 팔린 자리가 있으면
        // 상태와 배치도가 어긋나, 화면을 보는 쪽이 어느 쪽을 믿어야 할지 알 수 없다.
        List<Long> onSaleConcertIds = new ArrayList<>();
        for (ConcertSeed seed : CONCERT_SEEDS) {
            Long concertId = seedConcert(seed, venueId, artistIds);
            if (seed.status() == ConcertStatus.ON_SALE) {
                onSaleConcertIds.add(concertId);
            }
        }

        // 좌석 상태는 공연이 생긴 뒤에 입힌다. 선점·판매가 공연별 행이라 공연 없이는 만들 수 없다.
        markSomeSeatsTaken(venueId, onSaleConcertIds);

        log.info("로컬 시드: 공연 {}건을 넣었다. venueId={}", CONCERT_SEEDS.size(), venueId);
    }

    /**
     * 고정 공연장이 이미 있으면 그것을 쓴다. 등록 API 는 이름 중복을 409 로 막으므로 먼저 확인한다.
     */
    private Long findOrRegisterVenue() {
        return venueRepository.findByName(VENUE_NAME)
                .map(Venue::getId)
                .orElseGet(() -> venueService.register(new CommandVenueRequestDto(
                        VENUE_NAME,
                        VENUE_ADDRESS,
                        SECTION_SEEDS.size() * SEATS_PER_SECTION)).id());
    }

    /**
     * 공연장의 구역과 좌석을 한 번에 등록한다.
     *
     * <p>구역이 이미 있으면 넘어간다. 구역명은 공연장 안에서 유일해서, 남아 있는 배치도 위에 다시 등록하면
     * 기동이 409 로 실패한다.
     */
    private void seedSeats(Long venueId) {
        // 구역 조회 API 는 이제 공연 기준이라 여기 쓸 수 없다. "이 공연장에 구역이 있는가" 는
        // 공연과 무관한 질문이므로 리포지토리에 직접 묻는다.
        if (!sectionRepository.findAllByVenueIdOrderByIdAsc(venueId).isEmpty()) {
            log.info("공연장 {} 에 구역이 이미 있어 좌석 시드를 건너뛴다.", venueId);
            return;
        }

        // 구역마다 배치가 같으므로 자리 목록은 한 번만 만들어 공유한다. 읽기만 하니 나눠 써도 된다.
        List<SeatPositionRequest> positions = gridPositions();

        CommandSeatResponseDto registered = seatService.register(new CommandSeatRequestDto(
                venueId,
                SECTION_SEEDS.stream()
                        .map(seed -> new SectionLayout(
                                seed.name(), seed.price(), ROW_COUNT, SEAT_PER_ROW, positions))
                        .toList()));

        log.info("로컬 시드: 구역 {}개 · 좌석 {}석을 넣었다.",
                registered.sections().size(), registered.totalSeatCount());
    }

    /**
     * 시드 공연마다 일부 자리를 판매 완료 · 선점 중으로 만든다.
     *
     * <p>좌석 행에는 판매 상태가 없다. 배치도의 상태는 조회 시점에 {@code seat_hold} 와
     * {@code reservation} 을 조인해 계산되므로({@code SeatRepository.findSeatsWithStatus}),
     * 상태를 보이게 하려면 그 행을 실제로 넣는 수밖에 없다.
     *
     * <p><b>공연마다 같은 회원 풀을 다시 쓴다.</b> 유니크가 {@code (concert_id, member)} 라
     * "한 계정은 한 공연에서 하나" 일 뿐, 공연이 다르면 같은 사람이 또 잡을 수 있다. 그래서 필요한
     * 회원 수는 전체 좌석 수가 아니라 <b>공연 하나에서 판매·선점을 합쳐 필요한 수</b>다.
     *
     * <p>다만 판매자와 선점자는 같은 공연 안에서는 겹치면 안 된다. 이미 티켓을 산 회원이 같은 공연의
     * 다른 자리를 선점하려 하면 {@link SeatService#hold} 가 "1인 1매" 로 거절한다. 그래서 이 둘은
     * 회원 풀을 {@code [0, soldPerConcert)} · {@code [soldPerConcert, soldPerConcert+heldPerConcert)}
     * 로 나눠 쓴다.
     *
     * <p>판매를 먼저 넣는다. {@link SeatService#hold} 가 이미 팔린 자리를 거절하므로 순서가 뒤집히면
     * 겹치는 자리(117번째)에서 기동이 실패한다.
     */
    private void markSomeSeatsTaken(Long venueId, List<Long> concertIds) {
        List<Section> sections = sectionRepository.findAllByVenueIdOrderByIdAsc(venueId);
        Map<Long, List<Seat>> seatsBySection = sections.stream()
                .collect(Collectors.toMap(
                        Section::getId,
                        section -> seatRepository
                                .findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId())));

        SeatDemand demand = countSeatDemand(sections, seatsBySection);
        List<Member> holders = seedMembers(demand.sold() + demand.held());

        int soldTotal = 0;
        int heldTotal = 0;
        for (Long concertId : concertIds) {
            Concert concert = concertRepository.getReferenceById(concertId);
            int soldIndex = 0;
            int heldIndex = demand.sold();

            for (Section section : sections) {
                List<Seat> seats = seatsBySection.get(section.getId());
                for (int position = 1; position <= seats.size(); position++) {
                    Seat seat = seats.get(position - 1);

                    if (position % OCCUPIED_EVERY == 0) {
                        reservationRepository.save(Reservation.builder()
                                .concert(concert)
                                .member(holders.get(soldIndex++))
                                .seat(seat)
                                .build());
                        soldTotal++;
                    } else if (position % RESERVED_EVERY == 0) {
                        seatService.hold(holders.get(heldIndex++).getId(), concertId, seat.getId());
                        heldTotal++;
                    }
                }
            }
        }

        extendSeedHolds();

        log.info("로컬 시드: 공연 {}건에 판매 {}석 · 선점 {}석을 넣었다. 시드 회원 {}명.",
                concertIds.size(), soldTotal, heldTotal, holders.size());
        log.info("로컬 시드: 시드 계정으로 로그인할 수 있다. id={}001~{}{} / pw={}",
                SEED_MEMBER_USERNAME_PREFIX, SEED_MEMBER_USERNAME_PREFIX,
                String.format("%03d", holders.size()), SEED_MEMBER_PASSWORD);
    }

    /** 공연 하나에서 판매·선점에 각각 필요한 회원 수. */
    private record SeatDemand(int sold, int held) {
    }

    /**
     * 공연 하나에서 판매·선점 자리가 각각 몇 자리인지. {@code markSomeSeatsTaken} 의 판정과 똑같이
     * 9·13 배수가 겹치는 자리(117번째)는 판매만 센다 — 여기서 따로 세어 그 규칙이 어긋나면 회원 풀이
     * 실제로 쓰는 것보다 남거나 모자란다.
     *
     * <p>세어서 구한다. 배치도 크기나 주기 상수를 바꿨을 때 회원이 모자라
     * {@code IndexOutOfBoundsException} 으로 기동이 죽는 일이 없게 하기 위해서다.
     */
    private SeatDemand countSeatDemand(List<Section> sections, Map<Long, List<Seat>> seatsBySection) {
        int sold = 0;
        int held = 0;
        for (Section section : sections) {
            int seatCount = seatsBySection.get(section.getId()).size();
            for (int position = 1; position <= seatCount; position++) {
                if (position % OCCUPIED_EVERY == 0) {
                    sold++;
                } else if (position % RESERVED_EVERY == 0) {
                    held++;
                }
            }
        }
        return new SeatDemand(sold, held);
    }

    /**
     * 좌석을 붙들어 둘 시드 회원을 만든다.
     *
     * <p>가입 API 를 거치지 않는다. {@code SignupService} 는 SMS 인증 티켓을 요구해 기동 중에는
     * 통과할 수 없고, 지갑 생성까지 딸려 와 좌석 상태를 보는 데 필요 없는 일이 늘어난다.
     * 그래서 {@link Member} · {@link LoginInfo} 의 공개 빌더만 쓴다 — 두 도메인 모두 건드리지 않는다.
     *
     * <p>지갑은 만들지 않는다. 좌석·주문 어느 쪽도 지갑을 요구하지 않고, 지갑 생성은 키 유도가 붙어
     * 회원마다 수백 ms 가 든다. 지갑이 필요한 화면을 이 계정으로 보려 하면 그때 함께 넣는다.
     *
     * <p><b>비밀번호 해시는 한 번만 계산해 전원이 나눠 쓴다.</b> BCrypt 는 일부러 느리게 만든
     * 해시라 회원마다 돌리면 기동이 그만큼 길어진다. 시드 계정은 전부 같은 비밀번호이므로 해시도
     * 같아도 된다 — 로컬에만 있는 계정이라 해시를 공유해서 생기는 위험이 없다.
     */
    private List<Member> seedMembers(int count) {
        String passwordHash = passwordEncoder.encode(SEED_MEMBER_PASSWORD);

        List<Member> members = new ArrayList<>(count);
        for (int index = 1; index <= count; index++) {
            Member member = memberRepository.save(Member.builder()
                    .phoneNumber(SEED_MEMBER_PHONE_PREFIX + String.format("%04d", index))
                    .name("시드회원" + index)
                    .nickname(SEED_MEMBER_NICKNAME_PREFIX + index)
                    .build());

            loginInfoRepository.save(LoginInfo.builder()
                    .member(member)
                    .username(SEED_MEMBER_USERNAME_PREFIX + String.format("%03d", index))
                    .passwordHash(passwordHash)
                    .build());

            members.add(member);
        }
        return members;
    }

    /**
     * 시드 선점의 만료를 하루 뒤로 미룬다.
     *
     * <p>{@link SeatService#hold} 가 쓰는 5분은 상수라 호출하는 쪽에서 정할 수 없다. 그대로 두면
     * 기동 5분 뒤에 선점 자리가 전부 예매 가능으로 보여 화면에서 확인할 시간이 없다.
     *
     * <p>{@code HELD} 를 전부 미뤄도 되는 이유는, 이 메서드가 공연이 하나도 없을 때만 도는
     * 시드 경로에 있어 여기 있는 {@code HELD} 는 방금 시드가 만든 것뿐이기 때문이다.
     */
    private void extendSeedHolds() {
        entityManager.createQuery("""
                        update SeatHold h
                        set h.expiresAt = :expiresAt
                        where h.status = com.ssafy.timo.domain.seat.entity.SeatHoldStatus.HELD
                        """)
                .setParameter("expiresAt", LocalDateTime.now(clock).plus(SEED_HOLD_DURATION))
                .executeUpdate();
    }

    /**
     * 격자를 빈자리 없이 채운 자리 목록. 행 우선으로 나열해 배치도 순서와 같다.
     */
    private List<SeatPositionRequest> gridPositions() {
        List<SeatPositionRequest> positions = new ArrayList<>(SEATS_PER_SECTION);
        for (int seatNo = 1; seatNo <= ROW_COUNT; seatNo++) {
            for (int seatCol = 1; seatCol <= SEAT_PER_ROW; seatCol++) {
                positions.add(new SeatPositionRequest(seatNo, seatCol));
            }
        }
        return positions;
    }

    /**
     * 시드가 쓰는 아티스트를 이름으로 한 번에 찾는다.
     *
     * <p>동명이인이 있으면 먼저 조회된 쪽을 쓴다. {@code artist_name} 에 unique 제약이 없어 가능한
     * 상황이지만, 시드 아티스트는 {@code db/seed-local.sql} 이 넣는 4명뿐이라 실제로는 생기지 않는다.
     *
     * @throws IllegalStateException 시드가 참조하는 이름이 하나라도 없는 경우. 없는 채로 진행하면
     *                               공연 생성이 {@code ArtistNotFoundException} 으로 죽는데, 그보다 원인이 드러나는 편이 낫다.
     */
    private Map<String, Long> findArtistIdsByName() {
        List<String> names = CONCERT_SEEDS.stream()
                .flatMap(seed -> seed.artistNames().stream())
                .distinct()
                .toList();

        Map<String, Long> idsByName = artistRepository.findAllByNameIn(names).stream()
                .collect(Collectors.toMap(Artist::getName, Artist::getId, (first, duplicate) -> first));

        List<String> missing = names.stream()
                .filter(name -> !idsByName.containsKey(name))
                .toList();
        if (!missing.isEmpty()) {
            throw new IllegalStateException(
                    "시드 아티스트가 없습니다. db/seed-local.sql 을 확인하세요. missing=" + missing);
        }

        return idsByName;
    }

    private Long seedConcert(ConcertSeed seed, Long venueId, Map<String, Long> artistIds) {
        CommandConcertResponseDto created = concertService.create(new CommandConcertRequestDto(
                seed.title(),
                seed.genre(),
                seed.posterImageKey(),
                seed.imageKeys(),
                seed.description(),
                seed.ageRating(),
                seed.startDate(),
                seed.endDate(),
                seed.openAt(),
                venueId,
                seed.artistNames().stream().map(artistIds::get).toList()));

        applySeedState(created.id(), seed);

        return created.id();
    }

    /**
     * 시드가 정한 상태와 조회수를 입힌다.
     *
     * <p>{@link Concert} 는 갓 만든 공연을 항상 {@code SCHEDULED}·조회수 0 으로 두고 이를 바꿀 수단을
     * 열어 두지 않는다. 상태 전이 API 가 아직 없어서다. 시드를 위해 엔티티에 setter 를 뚫는 대신
     * 여기서만 쓰는 갱신으로 처리한다. 상태 전이 API 가 생기면 이 메서드는 지우고 그 API 를 부른다.
     *
     * <p>이 값이 있어야 목록의 상태 필터와 인기순 정렬을 눌러 볼 수 있다.
     */
    private void applySeedState(Long concertId, ConcertSeed seed) {
        entityManager.createQuery("""
                        update Concert c
                        set c.status = :status, c.viewCount = :viewCount
                        where c.id = :id
                        """)
                .setParameter("status", seed.status())
                .setParameter("viewCount", seed.viewCount())
                .setParameter("id", concertId)
                .executeUpdate();

        // 벌크 업데이트는 영속성 컨텍스트를 갱신하지 않는다. 방금 만든 concertId 는 이미 SCHEDULED 로
        // 캐시돼 있어, 비우지 않으면 뒤이은 markSomeSeatsTaken 의 SeatService#hold 호출이 이 상태를
        // 그대로 읽어 "예매 중이 아닌 공연" 으로 거절한다. clear() 는 flush 되지 않은 변경을 그냥
        // 버리므로, seedSeats 가 아직 flush 하지 않은 Section.seatCount 변경(좌석 등록 시 채운 값)까지
        // 함께 날리지 않도록 먼저 flush 한다.
        entityManager.flush();
        entityManager.clear();
    }
}
