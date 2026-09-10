package com.ssafy.timo.stub;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.seat.entity.SeatStatus;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

/**
 * 스텁이 공유하는 고정 데이터.
 *
 * <p>도메인을 가로질러 일관돼야 한다. 공연 상세의 {@code venueId} 로 구역 목록을 부르고, 그 구역의
 * 좌석을 조회하고, 그 좌석을 선점하는 흐름이 한 번에 이어져야 프론트가 화면을 끝까지 붙여 볼 수 있다.
 * 그래서 공연장·구역·공연·아티스트를 한 곳에 둔다.
 *
 * <p>아티스트 id 와 이름은 {@code db/seed-local.sql} 과 같다. 로컬에서 v0 와 v1 을 오가며 봐도
 * 같은 이름이 나오게 하려는 것이다.
 */
public final class StubFixtures {

    /**
     * NotFound 를 재현하는 예약 id. 공연·공연장·구역·좌석·아티스트 어디에 넣어도 그 도메인의 404 가 난다.
     *
     * <p>좌석 id 는 구역 id 로부터 만들어지는 값이라({@link #seatId}) 자연히 생기지 않는 값이면 된다.
     * 404 는 구역 0 의 404 번째 자리인데, 구역 0 은 없으므로 좌석 404 도 없다.
     */
    public static final long NOT_FOUND_ID = 404L;

    /** 좌석 선점 유지 시간. 실제 규약(5분)과 같다. */
    public static final int HOLD_MINUTES = 5;

    // ---- 예매 -----------------------------------------------------------------------------------

    /**
     * 주문 확정 뒤 온체인 발행이 "끝난 것으로" 보이기까지의 시간. 화면이 폴링으로 상태 변화를 볼 수 있게
     * 즉시 MINTED 로 두지 않는다.
     */
    public static final int MINT_DELAY_SECONDS = 3;

    /** 발행 실패를 재현하는 예약 좌석. A블록 2행 3번. 이 좌석의 주문은 MINT_FAILED 를 거쳐 REFUNDED 가 된다. */
    public static final long MINT_FAIL_SEAT_ID = 1006L;

    /** 실패 좌석의 주문이 MINT_FAILED 에서 REFUNDED 로 넘어가기까지의 시간. */
    public static final int REFUND_DELAY_SECONDS = 3;

    /** 실패 재현 시 응답에 싣는 사유. 실제라면 revert 이름·메시지가 들어간다. */
    public static final String MINT_FAILURE_REASON = "SaleNotOpen(showId=1): 3회 재시도 실패 (스텁 재현)";

    /** 스텁이 새로 만드는 리소스의 시작 id. 고정 데이터 id(1~) 와 겹치지 않게 띄운다. */
    public static final long CREATED_ID_START = 100L;

    // ---- 공연장 ---------------------------------------------------------------------------------

    public static final long VENUE_ID = 1L;
    public static final String VENUE_NAME = "고척돔";
    public static final String VENUE_ADDRESS = "서울시 구로구 경인로 430";

    // ---- 구역 · 좌석 ------------------------------------------------------------------------------

    /** 격자 위 한 자리. */
    public record Cell(int seatNo, int seatCol) {
    }

    /**
     * 구역 하나의 배치. 좌석은 격자를 채우되 {@code aisleCols} 열 전체와 {@code holes} 자리는 통로로 비운다.
     *
     * <p>좌석 id 는 저장하지 않고 {@link #seatId} 로 계산한다. 그래야 선점 API 가 좌석 id 하나로
     * 어느 구역의 어느 자리인지 되짚을 수 있다.
     */
    public record SectionFixture(
            long id,
            String name,
            int price,
            int rowCount,
            int seatPerRow,
            Set<Integer> aisleCols,
            Set<Cell> holes
    ) {
        public boolean hasSeat(int seatNo, int seatCol) {
            return seatNo >= 1 && seatNo <= rowCount
                    && seatCol >= 1 && seatCol <= seatPerRow
                    && !aisleCols.contains(seatCol)
                    && !holes.contains(new Cell(seatNo, seatCol));
        }

        /** 실제로 존재하는 자리 수. 격자 크기에서 통로를 뺀 값이다. */
        public int seatCount() {
            int count = 0;
            for (int seatNo = 1; seatNo <= rowCount; seatNo++) {
                for (int seatCol = 1; seatCol <= seatPerRow; seatCol++) {
                    if (hasSeat(seatNo, seatCol)) {
                        count++;
                    }
                }
            }
            return count;
        }
    }

    /** 첫 구역은 API 명세 예시와 같은 2행 3열, 2행 2번이 통로로 빈 배치(5석)다. */
    public static final List<SectionFixture> SECTIONS = List.of(
            new SectionFixture(1L, "1층 A블록", 150_000, 2, 3, Set.of(), Set.of(new Cell(2, 2))),
            new SectionFixture(2L, "1층 B블록", 150_000, 5, 8, Set.of(), Set.of()),
            new SectionFixture(3L, "2층 C블록", 99_000, 10, 10, Set.of(5), Set.of()));

    public static final SeatGrade SEAT_GRADE = SeatGrade.COMMON;

    /** 좌석 id 를 구역 id 와 격자 위치에서 만든다. 자리 번호는 1 부터 행 우선으로 매긴다. */
    private static final long SEAT_ID_SECTION_MULTIPLIER = 1_000L;

    public static Optional<SectionFixture> findSection(long sectionId) {
        return SECTIONS.stream().filter(section -> section.id() == sectionId).findFirst();
    }

    public static boolean hasSeat(SectionFixture section, int seatNo, int seatCol) {
        return section.hasSeat(seatNo, seatCol);
    }

    public static long seatId(SectionFixture section, int seatNo, int seatCol) {
        return section.id() * SEAT_ID_SECTION_MULTIPLIER + (long) (seatNo - 1) * section.seatPerRow() + seatCol;
    }

    /** 좌석 id 를 되짚어 자리를 찾는다. 격자 밖이거나 통로면 비어 있다. */
    public static Optional<SeatFixture> findSeat(long seatId) {
        long sectionId = seatId / SEAT_ID_SECTION_MULTIPLIER;
        int index = (int) (seatId % SEAT_ID_SECTION_MULTIPLIER);
        if (index < 1) {
            return Optional.empty();
        }

        return findSection(sectionId).flatMap(section -> {
            int seatNo = (index - 1) / section.seatPerRow() + 1;
            int seatCol = (index - 1) % section.seatPerRow() + 1;
            if (!hasSeat(section, seatNo, seatCol)) {
                return Optional.empty();
            }
            return Optional.of(new SeatFixture(seatId, section, seatNo, seatCol, initialStatus(index)));
        });
    }

    public record SeatFixture(long id, SectionFixture section, int seatNo, int seatCol, SeatStatus initialStatus) {
    }

    /**
     * 고정 배치도의 초기 상태. 자리 번호로 정해지는 결정적 규칙이라 조회할 때마다 같다.
     *
     * <p>A블록(5석)은 전부 {@code AVAILABLE} 이라 명세 예시와 같고, 큰 구역에는 팔린 자리와 남이 잡은
     * 자리가 군데군데 섞여 배치도 색 구분을 확인할 수 있다.
     */
    public static SeatStatus initialStatus(int index) {
        if (index % 9 == 0) {
            return SeatStatus.OCCUPIED;
        }
        if (index % 13 == 0) {
            return SeatStatus.RESERVED;
        }
        return SeatStatus.AVAILABLE;
    }

    // ---- 아티스트 ---------------------------------------------------------------------------------

    public record ArtistFixture(long id, String name, String profileImageKey) {
    }

    public static final Map<Long, ArtistFixture> ARTISTS = Map.of(
            1L, new ArtistFixture(1L, "김필", "artist/artist_kim_feel.jpg"),
            2L, new ArtistFixture(2L, "이승기", "artist/artist_lee_s.jpg"),
            3L, new ArtistFixture(3L, "로이킴", "artist/artist_roykim.jpg"),
            4L, new ArtistFixture(4L, "Bruno Mars", "artist/artist_bruno_mars.jpg"));

    // ---- 공연 -----------------------------------------------------------------------------------

    public record ConcertFixture(
            long id,
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
            long venueId,
            String venueName,
            List<Long> artistIds
    ) {
    }

    /**
     * 상태·장르·정렬 기준이 골고루 갈리도록 골랐다. 마지막 공연은 날짜가 전부 비어 있어
     * {@code OPEN_SOON}·{@code START_DATE} 정렬에서 뒤로 밀리는 동작을 볼 수 있다.
     */
    public static final List<ConcertFixture> CONCERTS = List.of(
            new ConcertFixture(1L, "김필 단독 콘서트", ConcertGenre.CONCERT,
                    "poster/poster_main_kim_feel.gif",
                    List.of("detail/poster_detail_kim.jpg"),
                    "김필 단독 콘서트", AgeRating.AGE_7, ConcertStatus.ON_SALE, 1_203,
                    LocalDateTime.of(2026, 10, 10, 19, 0), LocalDateTime.of(2026, 10, 12, 21, 0),
                    LocalDateTime.of(2026, 9, 1, 20, 0), VENUE_ID, VENUE_NAME, List.of(1L)),
            new ConcertFixture(2L, "이승기 콘서트", ConcertGenre.CONCERT,
                    "poster/poster_main_lee.gif",
                    List.of("detail/poster_detail_lee.jpg"),
                    "이승기 단독 콘서트", AgeRating.ALL, ConcertStatus.SCHEDULED, 512,
                    LocalDateTime.of(2026, 11, 21, 18, 0), LocalDateTime.of(2026, 11, 22, 21, 0),
                    LocalDateTime.of(2026, 10, 15, 20, 0), VENUE_ID, VENUE_NAME, List.of(2L)),
            new ConcertFixture(3L, "로이킴 콘서트", ConcertGenre.CONCERT,
                    "poster/poster_main_roykim.jpg",
                    List.of(),
                    "로이킴 단독 콘서트", AgeRating.AGE_7, ConcertStatus.SOLD_OUT, 3_300,
                    LocalDateTime.of(2026, 9, 20, 19, 30), LocalDateTime.of(2026, 9, 21, 21, 30),
                    LocalDateTime.of(2026, 8, 1, 14, 0), VENUE_ID, VENUE_NAME, List.of(3L)),
            new ConcertFixture(4L, "Bruno Mars 내한공연", ConcertGenre.CONCERT,
                    "poster/poster_main_mars.gif",
                    List.of("detail/poster_detail_mars.jpg"),
                    "Bruno Mars 내한 단독 공연", AgeRating.ALL, ConcertStatus.CLOSED, 87,
                    LocalDateTime.of(2026, 6, 1, 19, 0), LocalDateTime.of(2026, 6, 2, 21, 0),
                    LocalDateTime.of(2026, 5, 1, 20, 0), VENUE_ID, VENUE_NAME, List.of(4L)));

    public static Optional<ConcertFixture> findConcert(long concertId) {
        return CONCERTS.stream().filter(concert -> concert.id() == concertId).findFirst();
    }

    // ---- 양도 마켓 ---------------------------------------------------------------------------------

    /** 내 커스터디얼 지갑 주소. 로컬에는 회원이 하나뿐이라 고정값이다. */
    public static final String MY_WALLET_ADDRESS = "0x9f8e7d6c5b4a39281706f5e4d3c2b1a098765432";

    /** 남(고정 매물의 판매자, 내 매물을 사 가는 구매자)의 지갑 주소. */
    public static final String OTHER_WALLET_ADDRESS = "0x0a1b2c3d4e5f60718293a4b5c6d7e8f901234567";

    /** 고정 티켓의 발행·등록 시각. 1번 공연 예매 오픈(9/1 20:00) 직후로 잡았다. */
    public static final LocalDateTime FIXTURE_MINTED_AT = LocalDateTime.of(2026, 9, 1, 20, 5);
    public static final LocalDateTime FIXTURE_LISTED_AT = LocalDateTime.of(2026, 9, 5, 10, 0);

    /** 내가 올린 매물이 남에게 팔린 것으로 보이기까지의 시간. 판매자 화면 흐름을 보여 주기 위해서다. */
    public static final int LISTING_SOLD_AFTER_SECONDS = 10;

    /**
     * 양도 마켓의 고정 티켓.
     *
     * <p>{@code listPrice} 가 있으면 매물로 올라 있고, 없으면 보유 중(등록 가능)이다. {@code mine} 이 false 면
     * 남의 것이다. 좌석은 전부 고정 배치도에서 초기 상태가 {@code OCCUPIED} 인 자리를 골랐다
     * ({@link #initialStatus} 의 {@code index % 9 == 0}). 팔린 자리로 보이지 않으면 좌석 조회와 어긋난다.
     */
    public record MarketTicketFixture(String tokenId, long concertId, long seatId, boolean mine, Long listPrice) {
    }

    /**
     * tokenId 1~5 는 남의 매물, 101 은 내 보유 티켓이다.
     *
     * <p>내 티켓을 3번 공연(매진)에 둔 이유가 있다. 1번 공연 매물 3개는 사 볼 수 있어야 하고, 3번 공연 매물 2개는
     * 1인 1매로 막히는 것을 보여 줘야 한다. 내 티켓이 1번 공연이면 그 공연 매물을 하나도 살 수 없다.
     */
    public static final List<MarketTicketFixture> MARKET_TICKETS = List.of(
            new MarketTicketFixture("1", 1L, 2009L, false, 150_000L),
            new MarketTicketFixture("2", 1L, 2018L, false, 135_000L),
            new MarketTicketFixture("3", 1L, 2027L, false, 120_000L),
            new MarketTicketFixture("4", 3L, 3009L, false, 99_000L),
            new MarketTicketFixture("5", 3L, 3018L, false, 90_000L),
            new MarketTicketFixture("101", 3L, 3036L, true, null));

    /** 내가 처음부터 보유한, 등록 가능한 티켓. 문서와 스모크 테스트가 이 값을 쓴다. */
    public static final String MY_TICKET_TOKEN_ID = "101";

    private StubFixtures() {
    }
}
