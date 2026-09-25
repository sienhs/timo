package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.blockchain.MintResult;
import com.ssafy.timo.domain.blockchain.ShowRegistryClient;
import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;
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
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.seat.service.SeatService;
import com.ssafy.timo.domain.wallet.service.WalletService;
import com.ssafy.timo.global.storage.ImageStorage;

import jakarta.persistence.EntityManager;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.env.Environment;
import org.springframework.core.io.ClassPathResource;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.math.BigInteger;
import java.net.URLConnection;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 로컬 기동 시 데모 데이터를 DB 에 채운다. 공연장 1곳 → 좌석 배치도 → 공연 4건 순이다.
 *
 * <p>시드 값은 이 클래스가 직접 들고 있다. 같은 데모 데이터를 v0 스텁도 갖고 있지만
 * ({@code com.ssafy.timo.stub.StubFixtures}) 거기서 가져오지 않는다. 스텁은 v1 이 갖춰지면 지울
 * 임시 코드라, 지우는 순간 이 시더가 함께 깨진다. 공연이 이 4건인 것은 스텁 때문이 아니라 가진
 * 포스터·프로필 이미지와 {@code db/seed-local.sql} 이 넣는 아티스트가 그 4명이기 때문이다.
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
 * <p>{@code local}·{@code demo}·{@code prod} 프로필에서 등록된다. 운영에서는 RDS에 공연이 없을 때만
 * 한 번 실행돼 초기 데모 카탈로그를 만든다. 공연이 이미 있으면 {@link #run}이 즉시 건너뛴다.
 * 로컬·데모에서는 휘발성 DB를 전제로 매 기동 시 채워진다. 운영에서 이 빈이 무심코 다시 돌면 가짜
 * 공연이 쌓인다. {@code demo}는 DB 는 {@code local} 과 같은 휘발성 도커 MySQL 을 그대로 쓰고 이미지
 * 저장소만 실제 S3({@link com.ssafy.timo.global.storage.S3ImageStorage})로 바꾼 프로필이다
 * ({@code application-demo.yml} 참고).
 *
 * <p><b>이미지 key 는 어느 프로필에서나 같다.</b> 시드에 적힌 key 가 그대로 DB 에 들어가고,
 * 그 key 로 된 객체가 이미지 버킷에 있어야 화면에 보인다({@link ImageStorage#getUrl} 이 CDN 주소를
 * 앞에 붙일 뿐이다). 운영은 예전부터 이 값을 그대로 넣고 있었으므로, 이미 들어간 운영 데이터와도
 * 어긋나지 않는다.
 *
 * <p><b>버킷을 채우는 것은 {@code demo} 프로필 한 곳뿐이다</b>({@link #uploadSeedImages}).
 * {@code src/main/resources/static} 의 파일을 읽어 <b>같은 key 로</b> 올린다 - 그래서 demo 로 한 번
 * 띄우면 객체가 제자리에 놓이고, 그 뒤로는 정적 파일이 없어도(그 파일들을 지우는 것이
 * {@code S15P21D206-278} 의 목적이다) local·prod 가 같은 key 를 그대로 쓴다. 운영은 이 경로를 타지
 * 않으므로 jar 안에 이미지가 없어도 기동한다.
 *
 * <p><b>{@code ON_SALE} 공연은 실제 체인에도 등록한다.</b> {@code ReservationService}가 예매를
 * 받으려면 {@code Concert.isReadyForBooking()}(주최자·정가·온체인 showId)이 갖춰져 있어야 하는데,
 * 이걸 만드는 API가 따로 없다(주최사용 플랫폼을 만들 계획이 없어서다) - 그래서 더미데이터를 만드는
 * 이 시더가 유일한 소스가 되어, 좌석까지 다 만든 뒤 그 자리에서 {@code ShowRegistry.registerShow}를
 * 호출하고 받은 showId를 그대로 저장한다. 이 클래스는 {@link #run}이 공연 하나도 없을 때만 도는
 * 만큼(위 참고) 이 체인 호출도 <b>DB가 빈 최초 1회</b>뿐이고, 이후 재기동에는 없다.
 *
 * <p>체인에 접근할 수 없는 환경(방화벽·{@code ADMIN_PRIVATE_KEY} 없음)에서도 로컬 기동 자체는
 * 실패하면 안 된다 - 블록체인과 무관한 화면 작업을 하는 사람까지 막을 이유가 없다. 그래서 공연별로
 * 실패를 잡아 경고 로그만 남기고, 그 공연은 {@code SCHEDULED}로 되돌린다. {@code ON_SALE}인데
 * {@code isReadyForBooking()}이 false인 상태를 남기면 {@code ReservationServiceImpl.create()}가
 * 그걸 불변식 위반(500)으로 보고 던지기 때문에, "체인 미등록"은 항상 "아직 판매 전"(409)으로
 * 보여야 한다.
 */
@Slf4j
@Component
@Profile({"local", "demo"})
@RequiredArgsConstructor
public class LocalDataSeeder implements ApplicationRunner {

    /**
     * 이미 팔렸거나 남이 잡고 있는 자리를 섞는 주기. 구역 안 자리 번호가 이 수의 배수면 그 상태가 된다.
     *
     * <p>두 조건이 겹치는 자리(117번째)는 점유가 이긴다. v0 스텁이 쓰는 규칙과 같은 값이지만
     * 스텁에서 가져오지는 않는다 — 같은 의도를 따로 구현한 것이다.
     */
    /**
     * 시드 티켓의 {@code tokenId} 시작값.
     *
     * <p>진짜 발행은 체인이 번호를 매기고 작은 수부터 시작한다. 로컬에서 시드와 실제 예매를 섞어
     * 쓰면 {@code uk_ticket_token_id} 가 충돌할 수 있어, 겹칠 일이 없는 높은 대역을 쓴다.
     */
    private static final long SEED_TOKEN_ID_START = 1_000_000_000L;

    /**
     * 공연 하나에 열어 둘 시드 매물 수.
     *
     * <p>목록이 비어 보이지 않을 만큼만이다. 체인이 붙어 있으면 이 수만큼 온체인 발행이 일어나므로
     * ({@link #seedListings}) 늘릴수록 최초 기동이 느려진다.
     */
    private static final int LISTINGS_PER_CONCERT = 2;

    /** 시드 등록가는 정가의 이 비율이다. 정가 초과는 등록 자체가 막히므로 100 을 넘기면 안 된다. */
    private static final int SEED_LIST_PRICE_PERCENT = 90;

    /**
     * 시드 매물의 등록 시각. <b>어제여야 한다.</b>
     *
     * <p>매물은 등록 다음 날 08:00 부터 남에게 보인다({@code MarketHoursService.visibleBefore}).
     * 오늘로 두면 기동 당일에는 목록에도 없고 구매도 409 라 데모가 성립하지 않는다.
     */
    private static final LocalTime LISTED_AT_TIME = LocalTime.of(20, 0);

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
     * 온체인 등록에 쓰는 주최자 계정. 좌석을 붙드는 시드 회원 풀({@code SEED_MEMBER_PHONE_PREFIX})과
     * 접두를 다르게 둬서 번호·닉네임이 겹치지 않는다.
     *
     * <p>지갑까지 만든다({@link WalletService#createWallet}) - {@code chargeForBooking}이 주최자
     * 지갑 주소로 대금을 적립하므로, 좌석 시드용 회원과 달리 지갑이 반드시 있어야 한다.
     */
    private static final String SEED_ORGANIZER_PHONE = "01099019999";
    private static final String SEED_ORGANIZER_NICKNAME = "시드주최";
    private static final String SEED_ORGANIZER_NAME = "시드주최사";

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

    // ---- 공연 -----------------------------------------------------------------------------------

    /**
     * 공연 하나의 시드 정보.
     *
     * <p>이미지는 URL 이 아니라 저장소 key 다. 이 key 로 된 객체가 이미지 버킷에 있어야 화면에
     * 보이고({@link ImageStorage#getUrl} 이 CDN 주소를 앞에 붙인다), 그 객체를 올리는 것은
     * {@code demo} 프로필의 {@link #uploadSeedImages} 하나뿐이다 - 클래스 상단 주석 참고.
     * 여기 key 를 바꾸면 {@code src/main/resources/static} 아래 같은 경로에 파일을 두고 demo 로 한 번
     * 띄워야 한다.
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
     * 시드 공연 4건. 버킷의 {@code poster/} 아래 포스터 하나에 공연 하나씩이다.
     *
     * <p>상태·장르·조회수가 골고루 갈리도록 골랐다. 그래야 목록의 상태 필터와 인기순 정렬을 눌러 볼 수
     * 있다. 로이킴 공연만 상세 이미지가 비어 있는데, {@code detail/} 아래에 해당 객체가 없어서다 —
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
     * <p>고정 캘린더 날짜가 아니라 {@link #clock} 기준 상대 오프셋으로 계산한다({@link #concertSeeds}) -
     * 시간이 지나도 이 관계가 저절로 유지되어, 재시드할 때마다 날짜를 손으로 미룰 필요가 없다.
     */
    private List<ConcertSeed> concertSeeds() {
        LocalDateTime now = LocalDateTime.now(clock);
        return List.of(
                // 내역. 이미 끝난 공연이라 예매 화면이 아니라 지난 공연 목록에서 확인한다.
                new ConcertSeed("김필 단독 콘서트", ConcertGenre.CONCERT,
                        "poster/poster_main_kim_feel.gif",
                        List.of("detail/poster_detail_kim.jpg"),
                        "김필 단독 콘서트", AgeRating.AGE_7, ConcertStatus.CLOSED, 1_203,
                        now.minusDays(60), now.minusDays(60).plusHours(2),
                        now.minusDays(120), List.of("김필")),
                // 대기. 오픈이 아직 남아 좌석 화면에 들어갈 수 없다.
                new ConcertSeed("이승기 콘서트", ConcertGenre.CONCERT,
                        "poster/poster_main_lee.gif",
                        List.of("detail/poster_detail_lee.jpg"),
                        "이승기 단독 콘서트", AgeRating.ALL, ConcertStatus.SCHEDULED, 512,
                        now.plusDays(60), now.plusDays(60).plusHours(3),
                        now.plusDays(30), List.of("이승기")),
                // 예매 중. 좌석 상태가 들어가는 두 건 중 하나다.
                new ConcertSeed("로이킴 콘서트", ConcertGenre.CONCERT,
                        "poster/poster_main_roykim.jpg",
                        List.of(),
                        "로이킴 단독 콘서트", AgeRating.AGE_7, ConcertStatus.ON_SALE, 3_300,
                        now.plusDays(30), now.plusDays(30).plusHours(2),
                        now.minusDays(30), List.of("로이킴")),
                // 예매 중. 좌석 상태가 들어가는 두 건 중 하나다.
                new ConcertSeed("Bruno Mars 내한공연", ConcertGenre.CONCERT,
                        "poster/poster_main_mars.gif",
                        List.of("detail/poster_detail_mars.jpg"),
                        "Bruno Mars 내한 단독 공연", AgeRating.ALL, ConcertStatus.ON_SALE, 87,
                        now.plusDays(45), now.plusDays(45).plusHours(2),
                        now.minusDays(10), List.of("Bruno Mars")),
                // 입장 QR 종단 테스트 전용. 입장 QR 발급 창(시작 2시간 전)이 열리기 몇 분 전에 시작해서,
                // 예매를 마치고 몇 분만 기다리면 QR 이 열린다(예매 마감은 시작 30분 전이라 그 뒤에도 남는다) -
                // 실제로 몇 시간을 기다리지 않고도 예매→발행→입장 QR까지 전체 흐름을 검증할 수 있게
                // 하려는 목적 하나뿐이다. Clock 을 앞당기는 대신 이 시드 자체를 "곧 시작하는 공연"으로
                // 두는 것이라 DB·온체인·화면이 항상 서로 일치한다.
                new ConcertSeed("입장 테스트 콘서트", ConcertGenre.CONCERT,
                        "poster/poster_main_roykim.jpg",
                        List.of(),
                        "종단 테스트 전용 공연", AgeRating.ALL, ConcertStatus.ON_SALE, 0,
                        now.plusHours(2).plusMinutes(3), now.plusHours(2).plusMinutes(3).plusHours(2),
                        now.minusHours(1), List.of("로이킴")));
    }

    private final ConcertService concertService;
    private final SeatService seatService;
    private final VenueSeatCatalogSeeder venueSeatCatalogSeeder;
    private final ConcertRepository concertRepository;
    private final SeatRepository seatRepository;
    private final SectionRepository sectionRepository;
    private final ArtistRepository artistRepository;
    private final MemberRepository memberRepository;
    private final LoginInfoRepository loginInfoRepository;
    private final ReservationRepository reservationRepository;
    private final TicketRepository ticketRepository;
    private final TicketListingRepository ticketListingRepository;
    private final TicketNftClient ticketNftClient;
    private final PasswordEncoder passwordEncoder;
    private final EntityManager entityManager;
    private final Clock clock;
    private final ShowRegistryClient showRegistryClient;
    private final WalletService walletService;
    private final BlockchainProperties blockchainProperties;
    private final ImageStorage imageStorage;
    private final Environment environment;

    /**
     * 공연이 하나라도 있으면 아무것도 하지 않는다.
     *
     * <p>로컬은 {@code ddl-auto: create-drop} 이라 보통 매 기동마다 비어 있지만, DB 를 남겨 두고 앱만
     * 재시작하는 경우에 같은 공연이 다시 쌓이는 것을 막는다.
     *
     * <p>이미지 업로드({@link #uploadSeedImages})만 그 앞에 둔다. 버킷을 채우는 일은 DB 에 공연이
     * 있는지와 무관한데, 건너뛰는 자리에 두면 DB 를 남겨 둔 채 demo 로 다시 띄웠을 때 조용히 아무것도
     * 올리지 않는다.
     */
    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        uploadSeedImages();

        long existing = concertRepository.count();
        if (existing > 0) {
            log.info("공연이 이미 {}건 있어 시드를 건너뛴다.", existing);
            return;
        }

        Long venueId = venueSeatCatalogSeeder.seedVenueAndSeats();

        Map<String, Long> artistIds = findArtistIdsByName();

        // 좌석 상태는 예매 중인 공연에만 넣는다. 오픈 전이거나 끝난 공연에 팔린 자리가 있으면
        // 상태와 배치도가 어긋나, 화면을 보는 쪽이 어느 쪽을 믿어야 할지 알 수 없다.
        List<ConcertSeed> concertSeeds = concertSeeds();
        List<OnSaleConcert> onSaleConcerts = new ArrayList<>();
        for (ConcertSeed seed : concertSeeds) {
            Long concertId = seedConcert(seed, venueId, artistIds);
            if (seed.status() == ConcertStatus.ON_SALE) {
                onSaleConcerts.add(new OnSaleConcert(concertId, seed));
            }
        }

        // 좌석 상태는 공연이 생긴 뒤에 입힌다. 선점·판매가 공연별 행이라 공연 없이는 만들 수 없다.
        List<Long> onSaleConcertIds = onSaleConcerts.stream().map(OnSaleConcert::id).toList();
        List<Reservation> sold = markSomeSeatsTaken(venueId, onSaleConcertIds);

        // 좌석 배치까지 끝난 뒤에 체인 등록을 한다 - 실패해도 이미 넣은 시드 데이터에는 영향이 없다.
        int totalSeats = VenueSeatCatalogSeeder.totalSeatCount();
        registerOnChain(onSaleConcerts, totalSeats, venueId);

        // 매물은 체인 등록 뒤에 연다. 온체인 발행에 공연의 showId 가 필요한데 그 값이 방금 채워졌다.
        seedListings(sold, venueId);

        log.info("로컬 시드: 공연 {}건을 넣었다. venueId={}", concertSeeds.size(), venueId);
    }

    /** {@code registerOnChain}에 필요한 최소 정보 - 공연 id와 그 시드(정가·시각 계산용). */
    private record OnSaleConcert(Long id, ConcertSeed seed) {
    }

    /**
     * {@code ON_SALE} 공연을 실제 체인에 등록해 예매를 받을 수 있는 상태로 만든다.
     *
     * <p>공연마다 독립적으로 실패를 잡는다. 한 공연의 체인 등록이 실패해도 나머지 공연과 이미 넣은
     * 시드 데이터는 그대로 살아 있어야 한다 - 로컬 기동 자체가 체인 접근 여부에 좌우되면 안 된다.
     */
    private void registerOnChain(List<OnSaleConcert> onSaleConcerts, int totalSeats, Long venueId) {
        if (onSaleConcerts.isEmpty()) {
            return;
        }
        if (!blockchainProperties.hasRealAdminPrivateKey()) {
            // 더미 키로는 시도해 봐야 실패한다 - 방화벽 타임아웃까지 기다리지 않고 곧바로 건너뛴다.
            // ADMIN_PRIVATE_KEY 를 export 하지 않은 로컬 개발자와 test/securitytest 프로필(항상
            // 더미 키)이 여기 해당한다.
            log.info("blockchain.admin-private-key 가 더미 값이라 온체인 등록을 건너뛴다.");
            return;
        }

        Member organizer = seedOrganizer();
        BigInteger totalSeatsWei = BigInteger.valueOf(totalSeats);
        // ShowRegistry.SECTION_COUNT(5)개 구역 가격을, 실제 Section 행이 갖고 있는 값 그대로,
        // ReservationSettlementRunner가 나중에 같은 순서(findAllByVenueIdOrderByIdAsc)로 인덱스를
        // 구하는 것과 어긋나지 않게 이 순서 그대로 온체인에 싣는다.
        List<BigInteger> sectionPrices = sectionRepository.findAllByVenueIdOrderByIdAsc(venueId).stream()
                .map(section -> BigInteger.valueOf(section.getPrice()))
                .toList();
        int registered = 0;

        for (OnSaleConcert onSale : onSaleConcerts) {
            ConcertSeed seed = onSale.seed();
            try {
                long saleOpenTime = seed.openAt().atZone(clock.getZone()).toEpochSecond();
                long showTime = seed.startDate().atZone(clock.getZone()).toEpochSecond();

                BigInteger showId = showRegistryClient.registerShow(
                        sectionPrices, totalSeatsWei, saleOpenTime, showTime, "local-seed:" + seed.title());

                Concert concert = concertRepository.getReferenceById(onSale.id());
                concert.prepareForSale(organizer);
                concert.confirmRegistered(showId);
                registered++;
            } catch (ContractCallException e) {
                // 방화벽·ADMIN_PRIVATE_KEY 미설정 등으로 체인에 닿지 못하는 로컬 환경을 위한 방어다.
                // 등록을 못 했으니 SCHEDULED 로 남겨, "판매 중인데 예매가 막히는" 어긋난 상태를 피한다.
                log.warn("공연 '{}' 온체인 등록 실패, SCHEDULED 로 되돌린다 - 체인 접근(방화벽·키)을 확인하라", seed.title(), e);
                applySeedState(onSale.id(), new ConcertSeed(
                        seed.title(), seed.genre(), seed.posterImageKey(), seed.imageKeys(), seed.description(),
                        seed.ageRating(), ConcertStatus.SCHEDULED, seed.viewCount(),
                        seed.startDate(), seed.endDate(), seed.openAt(), seed.artistNames()));
            }
        }

        log.info("로컬 시드: 공연 {}/{}건을 체인에 등록했다.", registered, onSaleConcerts.size());
    }

    /**
     * 온체인 등록을 대신 서명하는 admin 지갑과는 별개로, {@code chargeForBooking} 이 예매 대금을
     * 적립할 실제 지갑 주소가 필요해 회원+지갑을 만든다. 좌석을 붙드는 시드 회원과 달리 지갑이
     * 반드시 있어야 한다.
     */
    private Member seedOrganizer() {
        Member organizer = memberRepository.save(Member.builder()
                .phoneNumber(SEED_ORGANIZER_PHONE)
                .name(SEED_ORGANIZER_NAME)
                .nickname(SEED_ORGANIZER_NICKNAME)
                .build());
        walletService.createWallet(organizer);
        return organizer;
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
     *
     * @return 만들어진 판매 주문. {@link #seedListings} 가 이 가운데 일부를 매물로 연다
     */
    private List<Reservation> markSomeSeatsTaken(Long venueId, List<Long> concertIds) {
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
        List<Reservation> sold = new ArrayList<>();
        for (Long concertId : concertIds) {
            Concert concert = concertRepository.getReferenceById(concertId);
            int soldIndex = 0;
            int heldIndex = demand.sold();

            for (Section section : sections) {
                List<Seat> seats = seatsBySection.get(section.getId());
                for (int position = 1; position <= seats.size(); position++) {
                    Seat seat = seats.get(position - 1);

                    if (position % OCCUPIED_EVERY == 0) {
                        sold.add(reservationRepository.save(Reservation.builder()
                                .concert(concert)
                                .member(holders.get(soldIndex++))
                                .seat(seat)
                                .build()));
                        soldTotal++;
                    } else if (position % RESERVED_EVERY == 0) {
                        seatService.hold(holders.get(heldIndex++).getId(), concertId, seat.getId());
                        heldTotal++;
                    }
                }
            }
        }

        seedTickets(sold);
        extendSeedHolds();

        log.info("로컬 시드: 공연 {}건에 판매 {}석 · 선점 {}석을 넣었다. 시드 회원 {}명.",
                concertIds.size(), soldTotal, heldTotal, holders.size());
        log.info("로컬 시드: 시드 계정으로 로그인할 수 있다. id={}001~{}{} / pw={}",
                SEED_MEMBER_USERNAME_PREFIX, SEED_MEMBER_USERNAME_PREFIX,
                String.format("%03d", holders.size()), SEED_MEMBER_PASSWORD);

        return sold;
    }

    /**
     * 시드 예매마다 티켓을 한 장씩 만들어 발행까지 끝난 것으로 둔다.
     *
     * <p>실제 경로에서는 {@code ReservationServiceImpl.create} 가 주문과 티켓을 같은 트랜잭션에서
     * 만들고, 커밋 뒤 {@code ReservationSettlementService} 가 체인에 올려 {@code OWNED} 로 바꾼다.
     * 시더는 예매 행만 직접 넣으므로 그 두 단계가 통째로 빠져 있었다 - 그래서 시드 예매에는 티켓이
     * 없었고, 상세 조회는 {@code IllegalStateException} 으로 500 이 났으며 양도 등록은 시작조차
     * 할 수 없었다.
     *
     * <p><b>{@code OWNED} 까지 보내는 것이 요점이다.</b> {@code PENDING_MINT} 로 두면 양도 등록이
     * "발행 전 티켓" 으로 거절해({@code ListingService.register}) 로컬에서 마켓을 만져 볼 수 없다.
     *
     * <p>{@code tokenId} 와 {@code mintTxHash} 는 <b>체인에 없는 가짜다.</b> 시드 예매를 실제로
     * 민팅하려면 좌석 수만큼 온체인 트랜잭션을 보내야 해서 기동이 현실적이지 않다. 그래서 이 값들로
     * 온체인 호출을 하면 실패한다 - 로컬에서 시드 예매를 취소하면 {@code TicketNftClient.revoke} 가
     * 없는 토큰을 건드려 거절당한다. 티켓이 아예 없어 500 이 나던 것에서 바뀐 지점이라 적어 둔다.
     *
     * <p>주문 식별자에서 유도해 {@code uk_ticket_token_id} 충돌을 피한다. 한 주문에 티켓은 하나
     * ({@code uk_ticket_reservation})라 값도 하나로 정해진다.
     */
    private void seedTickets(List<Reservation> reservations) {
        List<Ticket> tickets = reservations.stream()
                .map(reservation -> {
                    Ticket ticket = Ticket.builder().reservation(reservation).build();
                    // 저장 전에 상태를 옮긴다. 영속성 컨텍스트의 변경 감지에 기대지 않아도 되고,
                    // INSERT 한 번으로 끝난다.
                    ticket.markMinted(seedTokenId(reservation), seedTxHash(reservation));
                    return ticket;
                })
                .toList();

        ticketRepository.saveAll(tickets);
        log.info("시드 티켓 {}장을 발행 완료 상태로 넣었다", tickets.size());
    }

    /**
     * 시드 주문 가운데 일부를 양도 매물로 연다. 마켓 화면이 빈 목록으로 뜨지 않게 하는 것이 목적이다.
     *
     * <p><b>등록 서비스를 거치지 않는다.</b> {@code ListingService.register} 는 등록 시각을
     * {@code now} 로 박는데, 매물은 <b>등록 다음 날</b>부터 남에게 보인다({@code MarketHoursService}).
     * 시드가 그 경로를 타면 기동 당일에는 아무것도 안 보여 데모가 성립하지 않는다. 그래서 여기서
     * 등록 시각을 어제로 두고 직접 만든다 - 주문과 티켓도 같은 이유로 리포지토리에 직접 넣는다.
     *
     * <p>체인이 붙어 있으면 <b>매물로 쓸 티켓만 실제로 발행한다.</b> {@link #seedTickets} 가 박아 둔
     * {@code tokenId} 는 체인에 없는 가짜라, 그대로 두면 구매자가 결제하는 순간 {@code Marketplace.buy}
     * 가 없는 토큰을 건드려 되돌려진다. 판매자 지갑도 이때 함께 만든다 - 없으면 등록과 체결 양쪽에서
     * {@code walletService.getAddress} 가 터진다.
     *
     * <p>전 좌석을 발행하지 않는 이유는 {@link #seedTickets} 주석과 같다. 매물 수만큼이면 공연당
     * 두 건이라 기동이 느려지지 않는다.
     */
    private void seedListings(List<Reservation> sold, Long venueId) {
        List<Section> sections = sectionRepository.findAllByVenueIdOrderByIdAsc(venueId);
        LocalDateTime listedAt = LocalDateTime.now(clock).toLocalDate().minusDays(1).atTime(LISTED_AT_TIME);
        boolean onChain = blockchainProperties.hasRealAdminPrivateKey();

        Map<Long, List<Reservation>> byConcert = sold.stream()
                .collect(Collectors.groupingBy(reservation -> reservation.getConcert().getId(),
                        java.util.LinkedHashMap::new, Collectors.toList()));

        // 판매자 지갑은 회원마다 하나다. 같은 시드 회원이 공연을 바꿔 가며 다시 나오므로 여기서 모은다.
        Map<Long, String> sellerAddresses = new java.util.HashMap<>();

        int opened = 0;
        for (List<Reservation> reservations : byConcert.values()) {
            for (Reservation reservation : reservations.stream().limit(LISTINGS_PER_CONCERT).toList()) {
                if (openSeedListing(reservation, sections, listedAt, onChain, sellerAddresses)) {
                    opened++;
                }
            }
        }

        log.info("로컬 시드: 양도 매물 {}건을 열었다. 온체인 발행={}", opened, onChain);
    }

    /** 매물 하나. 체인 호출이 실패하면 그 매물만 건너뛰고 나머지 시드는 살린다. */
    private boolean openSeedListing(Reservation reservation,
                                    List<Section> sections,
                                    LocalDateTime listedAt,
                                    boolean onChain,
                                    Map<Long, String> sellerAddresses) {
        Ticket ticket = ticketRepository.findByReservationId(reservation.getId()).orElseThrow();
        Seat seat = reservation.getSeat();
        Section section = seat.getSection();
        long price = section.getPrice() * SEED_LIST_PRICE_PERCENT / 100;
        Member seller = reservation.getMember();

        if (onChain) {
            try {
                String sellerAddress = sellerAddresses.computeIfAbsent(
                        seller.getId(), id -> walletService.createWallet(seller).getAddress());
                // 가짜 tokenId 를 진짜로 갈아 끼운다. 상태는 이미 OWNED 라 바뀌지 않는다.
                MintResult minted = ticketNftClient.mintTicket(sellerAddress, reservation.getConcert().getShowId(),
                        BigInteger.valueOf(seat.getId()), sectionIndexOf(sections, section));
                ticket.markMinted(minted.tokenId(), minted.transactionHash());
                ticketNftClient.listForTransferFor(minted.tokenId(), sellerAddress, BigInteger.valueOf(price));
            } catch (ContractCallException e) {
                log.warn("시드 매물 온체인 준비 실패, 이 매물은 건너뛴다 (reservationId={})", reservation.getId(), e);
                return false;
            }
        }

        ticket.markListed();
        ticketListingRepository.save(TicketListing.open(
                ticket.getId(), seller.getId(), reservation.getConcert(), section,
                seat.getSeatNo(), seat.getSeatCol(), price, section.getPrice(), listedAt));
        return true;
    }

    /** {@code ReservationSettlementRunner} 와 같은 순서여야 온체인 구역 가격 배열과 어긋나지 않는다. */
    private int sectionIndexOf(List<Section> sections, Section section) {
        for (int index = 0; index < sections.size(); index++) {
            if (sections.get(index).getId().equals(section.getId())) {
                return index;
            }
        }
        throw new IllegalStateException("구역이 공연장 구역 목록에 없습니다 (sectionId=" + section.getId() + ")");
    }

    private static BigInteger seedTokenId(Reservation reservation) {
        return BigInteger.valueOf(SEED_TOKEN_ID_START + reservation.getId());
    }

    /** 체인에 없는 값이다. 형식만 진짜 해시와 같게 맞춘다 - 컬럼이 66자(0x + 64)다. */
    private static String seedTxHash(Reservation reservation) {
        return "0x" + String.format("%064x", reservation.getId());
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
     * 아티스트 프로필 이미지 key. {@code db/seed-local.sql} 이 로컬에 넣는 값과 같아야 한다 - 운영에는
     * 그 SQL 이 돌지 않아 {@link #findArtistIdsByName} 이 여기 값으로 아티스트를 직접 만든다.
     * 공연 이미지와 마찬가지로 {@link #uploadSeedImages} 가 이 key 로 객체를 올린다.
     */
    private static final Map<String, String> ARTIST_SEED_IMAGE_KEYS = Map.of(
            "김필", "artist/artist_kim_feel.jpg",
            "이승기", "artist/artist_lee_s.jpg",
            "로이킴", "artist/artist_roykim.jpg",
            "Bruno Mars", "artist/artist_bruno_mars.jpg");

    /**
     * 시드가 참조하는 이미지를 클래스패스에서 읽어 <b>같은 key 로</b> 버킷에 올린다. {@code demo}
     * 에서만 돈다 - 버킷을 처음 채우거나 이미지를 갈아 끼울 때 쓰는 자리다. aws CLI 가 없어도 이
     * 프로필로 한 번 띄우면 객체가 제자리에 놓인다.
     *
     * <p>{@link ImageStorage#upload} 가 아니라 {@link ImageStorage#uploadTo} 를 쓰는 것이 요점이다.
     * 전자는 저장소가 무작위 key 를 새로 만들어, 올릴 때마다 그 값을 시드와 이미 들어간 운영 DB 에
     * 옮겨 적어야 한다. 시드 key 에 그대로 쓰면 몇 번을 돌려도 결과가 같고, 정적 파일을 지운 뒤에도
     * 그 key 가 계속 유효하다.
     *
     * <p>{@code local}·{@code prod} 에서는 아무 일도 하지 않는다. local 은 저장소가
     * {@code PlaceholderImageStorage} 라 올릴 곳이 없고, 운영은 jar 안에 이미지 원본이 없다 -
     * 운영에서 이 경로를 켜면 {@link #loadClasspathImage} 가 그 자리에서 기동을 실패시킨다.
     */
    private void uploadSeedImages() {
        if (!environment.matchesProfiles("demo")) {
            return;
        }

        Set<String> keys = new LinkedHashSet<>(ARTIST_SEED_IMAGE_KEYS.values());
        for (ConcertSeed seed : concertSeeds()) {
            if (seed.posterImageKey() != null) {
                keys.add(seed.posterImageKey());
            }
            keys.addAll(seed.imageKeys());
        }

        keys.forEach(key -> imageStorage.uploadTo(key, loadClasspathImage(key)));
        log.info("데모 시드: 이미지 {}개를 버킷에 올렸다. keys={}", keys.size(), keys);
    }

    /** {@code src/main/resources/static/<imageKey>} 를 읽어 업로드 가능한 형태로 감싼다. */
    private MultipartFile loadClasspathImage(String imageKey) {
        String resourcePath = "static/" + imageKey;
        try (var in = new ClassPathResource(resourcePath).getInputStream()) {
            byte[] content = in.readAllBytes();
            String contentType = URLConnection.guessContentTypeFromName(imageKey);
            return new ClasspathMultipartFile(imageKey, contentType, content);
        } catch (IOException e) {
            throw new UncheckedIOException("데모 시드 이미지 로딩 실패: " + resourcePath, e);
        }
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
        List<String> names = concertSeeds().stream()
                .flatMap(seed -> seed.artistNames().stream())
                .distinct()
                .toList();

        Map<String, Long> idsByName = artistRepository.findAllByNameIn(names).stream()
                .collect(Collectors.toMap(Artist::getName, Artist::getId, (first, duplicate) -> first));

        List<String> missing = names.stream()
                .filter(name -> !idsByName.containsKey(name))
                .toList();
        if (!missing.isEmpty()) {
            // 이 시더는 이제 local·demo 전용이라(prod는 ProdCatalogSeeder가 담당) 아티스트는
            // 항상 db/seed-local.sql이 먼저 넣어 둔 것으로 가정한다.
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
