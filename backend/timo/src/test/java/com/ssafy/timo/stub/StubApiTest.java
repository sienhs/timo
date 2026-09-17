package com.ssafy.timo.stub;

import com.ssafy.timo.global.exception.GlobalExceptionHandler;
import com.ssafy.timo.global.security.CurrentMemberArgumentResolver;
import com.ssafy.timo.global.storage.PlaceholderImageStorage;
import com.ssafy.timo.stub.concert.ConcertStore;
import com.ssafy.timo.stub.concert.ConcertStubController;
import com.ssafy.timo.stub.reservation.ReservationStubController;
import com.ssafy.timo.stub.seat.SeatStateStore;
import com.ssafy.timo.stub.seat.SeatStubController;
import com.ssafy.timo.stub.seat.SectionStubController;
import com.ssafy.timo.domain.transfer.service.MarketHoursService;
import com.ssafy.timo.global.config.MarketHoursProperties;
import com.ssafy.timo.stub.transfer.MarketStubController;
import com.ssafy.timo.stub.transfer.MarketTicketStore;
import com.ssafy.timo.stub.venue.VenueStubController;
import com.ssafy.timo.support.Authenticated;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;

import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.nullValue;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * v0 스텁 컨트롤러 검증.
 *
 * <p>스프링 컨텍스트를 띄우지 않는 standalone MockMvc 다. 스텁은 DB 도 인증도 필요 없고,
 * {@code IntegrationTest} 컨텍스트에 속성을 덧씌우면 컨텍스트가 하나 더 떠 전체 테스트가 느려진다.
 *
 * <p>다만 {@link CurrentMemberArgumentResolver} 는 직접 끼우고 요청자도 하나 정해 둔다.
 * {@code WebMvcConfig} 가 등록하는 리졸버라 standalone 에는 없고, 없으면 스텁이 전부 500 이 된다.
 *
 * <p>여기서 확인하려는 것은 두 가지다.
 * <ul>
 *   <li>인터페이스({@code *Api})에만 둔 매핑·{@code @Valid}·{@code @RequestParam} 이 구현 클래스에서
 *       그대로 살아 있는가. standalone 도 실제와 같은 {@code RequestMappingHandlerMapping} 을 쓴다.</li>
 *   <li>스텁이 명세와 같은 상태 코드·응답 필드를 내고, 예약값으로 실패 분기가 재현되는가.</li>
 * </ul>
 */
class StubApiTest {

    private static final Instant START = Instant.parse("2026-09-10T03:00:00Z");

    /** 스텁은 요청자를 쓰지 않는다. 리졸버가 401 을 내지 않을 만큼만 있으면 된다. */
    private static final long STUB_MEMBER_ID = 1L;

    /** 예매 스텁은 주문 뒤 흐른 시간으로 발행 상태를 정하므로 테스트가 시간을 움직일 수 있어야 한다. */
    private final MutableClock clock = new MutableClock(START);

    /**
     * 운영 시간 가드를 끈 판정 서비스. 시작 시각이 정오라 실제 규칙이면 목록·구매는 409 이고 가격
     * 수정만 되는데, 한 테스트가 둘을 오가는 경우가 많다. 가드 자체는 v1 쪽 테스트가 본다.
     * {@code status()} 는 그대로라 운영 시간 응답은 실제 규칙(정오 = 닫힘)으로 나온다.
     */
    private final MarketHoursService guardsOffMarket = new MarketHoursService(
            new MarketHoursProperties(LocalTime.of(20, 0, 0), LocalTime.of(23, 59, 59)), clock) {
        @Override
        public void requireOpen() {
        }

        @Override
        public void requireClosed() {
        }

        /** 스텁 테스트는 등록 직후 목록에 보이는 것을 전제한다. 다음 날 노출 규칙도 v1 쪽이 본다. */
        @Override
        public LocalDateTime visibleBefore() {
            return LocalDateTime.MAX;
        }
    };

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        SeatStateStore seatStateStore = new SeatStateStore();
        ConcertStore concertStore = new ConcertStore();
        // 예매 스텁과 마켓 스텁이 같은 티켓을 봐야 한다. 따로 만들면 예매로 받은 번호로 등록할 수 없다.
        MarketTicketStore ticketStore = new MarketTicketStore();
        PlaceholderImageStorage imageStorage = new PlaceholderImageStorage("https://cdn.stub.timo.io");
        mockMvc = MockMvcBuilders.standaloneSetup(
                        new VenueStubController(),
                        new ConcertStubController(concertStore, imageStorage),
                        new SectionStubController(seatStateStore),
                        new SeatStubController(seatStateStore, clock),
                        new ReservationStubController(seatStateStore, concertStore, ticketStore, imageStorage, clock),
                        new MarketStubController(ticketStore, concertStore, imageStorage, clock,
                                guardsOffMarket))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setCustomArgumentResolvers(new CurrentMemberArgumentResolver())
                .build();
        Authenticated.set(STUB_MEMBER_ID);
    }

    @AfterEach
    void clearAuthentication() {
        // 홀더는 스레드에 남는다. 비우지 않으면 다음 테스트가 이 요청자를 물려받는다.
        Authenticated.clear();
    }

    @Nested
    @DisplayName("공연장")
    class Venue {

        @Test
        void 등록하면_201과_Location을_v0_경로로_준다() throws Exception {
            mockMvc.perform(post("/api/v0/venues")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"name": "고척돔", "address": "서울시 구로구", "totalSeatCount": 16000}
                                    """))
                    .andExpect(status().isCreated())
                    .andExpect(header().string("Location", startsWith("/api/v0/venues/")))
                    .andExpect(jsonPath("$.id").isNumber())
                    .andExpect(jsonPath("$.name").value("고척돔"));
        }

        @Test
        void 인터페이스의_Valid_가_구현체에서도_걸린다() throws Exception {
            // totalSeatCount 는 primitive 라 빠지면 @Valid 전에 본문 매핑에서 400 이 난다. 검증 단계를 보려면 채워 둔다.
            mockMvc.perform(post("/api/v0/venues")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"totalSeatCount": 10}
                                    """))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("MethodArgumentNotValidException"))
                    .andExpect(jsonPath("$.errors[?(@.field == 'name')]").exists());
        }
    }

    @Nested
    @DisplayName("공연")
    class Concert {

        @Test
        void 목록은_PagedModel_모양이고_고정_공연이_들어_있다() throws Exception {
            mockMvc.perform(get("/api/v0/concerts"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content", hasSize(StubFixtures.CONCERTS.size())))
                    .andExpect(jsonPath("$.page.number").value(0))
                    .andExpect(jsonPath("$.page.size").value(20))
                    .andExpect(jsonPath("$.page.totalElements").value(StubFixtures.CONCERTS.size()))
                    .andExpect(jsonPath("$.content[0].artists").doesNotExist());
        }

        @Test
        void 장르_필터와_인기순_정렬이_적용된다() throws Exception {
            // 고정 공연 4건은 전부 CONCERT 다. 조회수 3300 > 1203 > 512 > 87.
            mockMvc.perform(get("/api/v0/concerts").param("genre", "CONCERT").param("sort", "POPULAR"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content", hasSize(4)))
                    .andExpect(jsonPath("$.content[0].id").value(3))
                    .andExpect(jsonPath("$.content[1].id").value(1))
                    .andExpect(jsonPath("$.content[3].id").value(4));
            mockMvc.perform(get("/api/v0/concerts").param("genre", "MUSICAL"))
                    .andExpect(jsonPath("$.content", hasSize(0)));
        }

        @Test
        void 기본_정렬은_등록_역순이다() throws Exception {
            mockMvc.perform(get("/api/v0/concerts"))
                    .andExpect(jsonPath("$.content[0].id").value(4))
                    .andExpect(jsonPath("$.content[3].id").value(1));
        }

        @Test
        void 오픈임박순은_openAt_오름차순이다() throws Exception {
            // openAt: 4번 5/1 < 3번 8/1 < 1번 9/1 < 2번 10/15
            mockMvc.perform(get("/api/v0/concerts").param("sort", "OPEN_SOON"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content[0].id").value(4))
                    .andExpect(jsonPath("$.content[1].id").value(3))
                    .andExpect(jsonPath("$.content[3].id").value(2));
        }

        @Test
        void 페이지_크기_상한을_넘기면_400() throws Exception {
            mockMvc.perform(get("/api/v0/concerts").param("size", "101"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.errors[?(@.field == 'size')]").exists());
        }

        @Test
        void 생성한_공연은_상세와_목록에서_바로_보인다() throws Exception {
            String requestJson = """
                    {
                      "title": "새 공연", "genre": "PLAY", "ageRating": "ALL",
                      "venueId": 1, "artistIds": [1, 1, 2],
                      "startDate": "2026-12-01T19:00:00", "endDate": "2026-12-02T19:00:00",
                      "openAt": "2026-11-01T20:00:00"
                    }
                    """;
            MockMultipartFile request = new MockMultipartFile(
                    "request", "", MediaType.APPLICATION_JSON_VALUE, requestJson.getBytes(StandardCharsets.UTF_8));
            MockMultipartFile poster = new MockMultipartFile(
                    "poster", "poster.png", MediaType.IMAGE_PNG_VALUE, "poster-bytes".getBytes(StandardCharsets.UTF_8));

            mockMvc.perform(multipart("/api/v0/concerts").file(request).file(poster))
                    .andExpect(status().isCreated())
                    .andExpect(header().string("Location", "/api/v0/concerts/" + StubFixtures.CREATED_ID_START))
                    .andExpect(jsonPath("$.status").value("SCHEDULED"))
                    .andExpect(jsonPath("$.viewCount").value(0))
                    .andExpect(jsonPath("$.posterImageUrl",
                            matchesPattern("https://cdn\\.stub\\.timo\\.io/concert/[^/]+/poster/[^/]+\\.png")))
                    .andExpect(jsonPath("$.artists", hasSize(2)))
                    .andExpect(jsonPath("$.artists[0].name").value("김필"));

            mockMvc.perform(get("/api/v0/concerts/" + StubFixtures.CREATED_ID_START))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.title").value("새 공연"));

            mockMvc.perform(get("/api/v0/concerts").param("genre", "PLAY"))
                    .andExpect(jsonPath("$.content", hasSize(1)));
        }

        @Test
        void 예약_id_로_조회하면_404() throws Exception {
            mockMvc.perform(get("/api/v0/concerts/" + StubFixtures.NOT_FOUND_ID))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ConcertNotFoundException"));
        }

        @Test
        void 종료일이_시작일보다_빠르면_400() throws Exception {
            MockMultipartFile request = new MockMultipartFile("request", "", MediaType.APPLICATION_JSON_VALUE, """
                    {"title": "t", "genre": "PLAY", "ageRating": "ALL", "venueId": 1, "artistIds": [1],
                     "startDate": "2026-12-02T19:00:00", "endDate": "2026-12-01T19:00:00"}
                    """.getBytes(StandardCharsets.UTF_8));

            mockMvc.perform(multipart("/api/v0/concerts").file(request))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("InvalidConcertPeriodException"));
        }
    }

    @Nested
    @DisplayName("구역 · 좌석")
    class SeatAndSection {

        @Test
        void 구역_목록은_잔여석_합계를_준다() throws Exception {
            mockMvc.perform(get("/api/v0/sections").param("concertId", "1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.venueId").value(1))
                    .andExpect(jsonPath("$.sections", hasSize(3)))
                    .andExpect(jsonPath("$.sections[0].seatCount").value(5))
                    .andExpect(jsonPath("$.sections[0].availableCount").value(5));
        }

        @Test
        void 구역_합계는_명세_문서의_값과_같다() throws Exception {
            // docs/stub/STUB_SEAT_API.md 의 고정 배치도 표와 맞아야 한다.
            mockMvc.perform(get("/api/v0/sections").param("concertId", "1"))
                    .andExpect(jsonPath("$.totalSeatCount").value(135))
                    .andExpect(jsonPath("$.totalAvailableCount").value(112))
                    .andExpect(jsonPath("$.sections[1].availableCount").value(33))
                    .andExpect(jsonPath("$.sections[2].seatCount").value(90))
                    .andExpect(jsonPath("$.sections[2].availableCount").value(74));
        }

        @Test
        void concertId_없이_부르면_400() throws Exception {
            mockMvc.perform(get("/api/v0/sections"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("MissingServletRequestParameterException"));
        }

        @Test
        void concertId_가_숫자가_아니면_400() throws Exception {
            mockMvc.perform(get("/api/v0/sections").param("concertId", "abc"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("MethodArgumentTypeMismatchException"));
        }

        @Test
        void A블록_좌석은_명세_예시와_같은_5석이다() throws Exception {
            mockMvc.perform(get("/api/v0/seats").param("concertId", "1").param("sectionId", "1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.rowCount").value(2))
                    .andExpect(jsonPath("$.seatPerRow").value(3))
                    .andExpect(jsonPath("$.seats", hasSize(5)))
                    .andExpect(jsonPath("$.seats[?(@.seatNo == 2 && @.seatCol == 2)]").doesNotExist())
                    .andExpect(jsonPath("$.seats[*].status", everyItem(is("AVAILABLE"))));
        }

        @Test
        void 선점하면_조회에_HELD_로_보이고_잔여석이_준다() throws Exception {
            long seatId = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 1);

            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId).param("concertId", "1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("HELD"))
                    .andExpect(jsonPath("$.expiresAt").value("2026-09-10T12:05:00"))
                    .andExpect(jsonPath("$.releasedSeatId").doesNotExist());

            mockMvc.perform(get("/api/v0/seats").param("concertId", "1").param("sectionId", "1"))
                    .andExpect(jsonPath("$.availableCount").value(4))
                    .andExpect(jsonPath("$.seats[0].status").value("HELD"));

            mockMvc.perform(get("/api/v0/sections").param("concertId", "1"))
                    .andExpect(jsonPath("$.sections[0].availableCount").value(4));
        }

        @Test
        void 다른_자리를_잡으면_이전_선점이_풀린다() throws Exception {
            long first = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 1);
            long second = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 2);

            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", first).param("concertId", "1")).andExpect(status().isOk());
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", second).param("concertId", "1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.releasedSeatId").value((int) first));

            mockMvc.perform(get("/api/v0/seats").param("concertId", "1").param("sectionId", "1"))
                    .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"))
                    .andExpect(jsonPath("$.seats[1].status").value("HELD"));
        }

        @Test
        void 남이_잡은_고정_좌석은_선점_403_취소_403() throws Exception {
            // C블록의 13 번째 자리는 초기 상태가 HELD 다. (StubFixtures.initialStatus)
            long seatId = StubFixtures.SECTIONS.get(2).id() * 1_000 + 13;

            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId).param("concertId", "1"))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("SeatNotHoldableException"));
            mockMvc.perform(delete("/api/v0/seats/{seatId}/hold", seatId).param("concertId", "1"))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"));
        }

        @Test
        void 없는_좌석은_404() throws Exception {
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", StubFixtures.NOT_FOUND_ID).param("concertId", "1"))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("SeatNotFoundException"));
        }

        @Test
        void 구역_등록은_격자_크기를_좌석_최대_번호로_채운다() throws Exception {
            mockMvc.perform(post("/api/v0/seats")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"venueId": 1, "sections": [{"name": "신규", "price": 1000,
                                      "seats": [{"seatNo": 1, "seatCol": 1}, {"seatNo": 2, "seatCol": 3}]}]}
                                    """))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.totalSeatCount").value(2))
                    .andExpect(jsonPath("$.sections[0].rowCount").value(2))
                    .andExpect(jsonPath("$.sections[0].seatPerRow").value(3))
                    .andExpect(jsonPath("$.sections[0].grade").value("COMMON"));
        }

        @Test
        void 한_요청_안_구역명_중복은_409() throws Exception {
            mockMvc.perform(post("/api/v0/seats")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"venueId": 1, "sections": [
                                      {"name": "A", "price": 1000, "seats": [{"seatNo": 1, "seatCol": 1}]},
                                      {"name": "A", "price": 1000, "seats": [{"seatNo": 1, "seatCol": 1}]}]}
                                    """))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("SectionNameDuplicatedException"));
        }
    }

    @Nested
    @DisplayName("예매")
    class Reservation {

        private final long seatId = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 1);

        private String body(long concertId, long seatId) {
            return """
                    {"concertId": %d, "seatId": %d}
                    """.formatted(concertId, seatId);
        }

        private void holdAndReserve(long concertId, long seatId) throws Exception {
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId).param("concertId", "1")).andExpect(status().isOk());
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content(body(concertId, seatId)))
                    .andExpect(status().isCreated());
        }

        @Test
        void 선점한_좌석으로_주문하면_201_PAID_이고_좌석은_SOLD_가_된다() throws Exception {
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId).param("concertId", "1")).andExpect(status().isOk());

            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content(body(1, seatId)))
                    .andExpect(status().isCreated())
                    .andExpect(header().string("Location", "/api/v0/reservations/" + StubFixtures.CREATED_ID_START))
                    .andExpect(jsonPath("$.status").value("PAID"))
                    .andExpect(jsonPath("$.orderId", startsWith("0x")))
                    .andExpect(jsonPath("$.tokenId").doesNotExist())
                    // 양도 등록이 받는 값. 주문 번호와 다른 값이어야 앱이 둘을 혼동하지 않는다.
                    .andExpect(jsonPath("$.ticketId").value(StubFixtures.ORDER_TICKET_ID_START))
                    .andExpect(jsonPath("$.id").value(StubFixtures.CREATED_ID_START))
                    .andExpect(jsonPath("$.facePrice").value(150000))
                    .andExpect(jsonPath("$.concertTitle").value("김필 단독 콘서트"))
                    .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                    .andExpect(jsonPath("$.mintAttemptCount").value(0));

            mockMvc.perform(get("/api/v0/seats").param("concertId", "1").param("sectionId", "1"))
                    .andExpect(jsonPath("$.seats[0].status").value("SOLD"));
        }

        @Test
        void 선점_없이_주문하면_409() throws Exception {
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content(body(1, seatId)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("SeatNotHeldException"));
        }

        @Test
        void 남이_잡은_좌석으로_주문하면_403() throws Exception {
            long othersSeat = StubFixtures.SECTIONS.get(2).id() * 1_000 + 13;   // 초기 상태 RESERVED
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content(body(1, othersSeat)))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"));
        }

        @Test
        void 예매_중이_아닌_공연은_409() throws Exception {
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId).param("concertId", "1"));
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content(body(2, seatId)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ConcertNotOnSaleException"));
        }

        @Test
        void 같은_공연을_두_번_예매하면_409() throws Exception {
            long second = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 2);
            holdAndReserve(1, seatId);

            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", second).param("concertId", "1"));
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content(body(1, second)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("AlreadyReservedException"));
        }

        @Test
        void 없는_공연_없는_좌석_없는_주문은_404() throws Exception {
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON)
                            .content(body(StubFixtures.NOT_FOUND_ID, seatId)))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ConcertNotFoundException"));
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON)
                            .content(body(1, StubFixtures.NOT_FOUND_ID)))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("SeatNotFoundException"));
            mockMvc.perform(get("/api/v0/reservations/{id}", StubFixtures.NOT_FOUND_ID))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ReservationNotFoundException"));
        }

        @Test
        void 필수값이_빠지면_400() throws Exception {
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content("{}"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.errors[?(@.field == 'concertId')]").exists())
                    .andExpect(jsonPath("$.errors[?(@.field == 'seatId')]").exists());
        }

        @Test
        void 목록은_PagedModel_이고_상태로_걸러지며_발행_정보는_없다() throws Exception {
            holdAndReserve(1, seatId);

            mockMvc.perform(get("/api/v0/reservations"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content", hasSize(1)))
                    .andExpect(jsonPath("$.content[0].status").value("PAID"))
                    .andExpect(jsonPath("$.content[0].tokenId").doesNotExist())
                    // 발행 정보는 없지만 티켓 번호는 목록에도 실린다 - 양도 등록 화면이 이 목록으로
                    // 고를 티켓을 만든다.
                    .andExpect(jsonPath("$.content[0].ticketId").value(StubFixtures.ORDER_TICKET_ID_START))
                    .andExpect(jsonPath("$.page.totalElements").value(1));

            mockMvc.perform(get("/api/v0/reservations").param("status", "CANCELLED"))
                    .andExpect(jsonPath("$.content", hasSize(0)));
        }
    }

    @Nested
    @DisplayName("양도 마켓")
    class Market {

        /** 내가 처음부터 보유한 티켓. 3번 공연 2층 C블록, 정가 99,000. 등록 전이라 매물이 아니다. */
        private static final long MY_TICKET_ID = Long.parseLong(StubFixtures.MY_TICKET_TOKEN_ID);

        /** 고정 매물은 티켓 순서대로 열리므로 listingId 가 곧 티켓 번호다. 1~3 은 1번 공연, 4~5 는 3번 공연. */
        private static final long OTHERS_LISTING_CONCERT1 = 3L;
        private static final long OTHERS_LISTING_CONCERT3 = 5L;

        private String listingBody(long ticketId, int price) {
            return """
                    {"ticketId": %d, "price": %d}
                    """.formatted(ticketId, price);
        }

        private String purchaseBody(int expectedPrice) {
            return """
                    {"expectedPrice": %d}
                    """.formatted(expectedPrice);
        }

        private ResultActions updatePrice(long listingId, int price) throws Exception {
            return mockMvc.perform(patch("/api/v0/market/listings/{listingId}/price", listingId)
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""
                            {"price": %d}
                            """.formatted(price)));
        }

        @Test
        @DisplayName("운영 시간 응답은 v1 과 같은 모양이다 - 정오라 닫혀 있고 다음 창은 오늘 20:00 이다")
        void hours() throws Exception {
            mockMvc.perform(get("/api/v0/market/hours"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.open").value(false))
                    .andExpect(jsonPath("$.serverTime").value("2026-09-10T12:00:00"))
                    .andExpect(jsonPath("$.opensAt").value("2026-09-10T20:00:00"))
                    .andExpect(jsonPath("$.closesAt").value("2026-09-10T23:59:59"));
        }

        private ResultActions purchase(long listingId, int expectedPrice) throws Exception {
            return mockMvc.perform(post("/api/v0/market/listings/{listingId}/purchase", listingId)
                    .header("Idempotency-Key", "11111111-1111-1111-1111-111111111111")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(purchaseBody(expectedPrice)));
        }

        @Test
        void 양도마켓_공연_목록은_매물_수와_최저가만_준다() throws Exception {
            mockMvc.perform(get("/api/v0/market/concerts"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content", hasSize(2)))
                    .andExpect(jsonPath("$.content[?(@.concertId == 1)].listingCount", contains(3)))
                    .andExpect(jsonPath("$.content[?(@.concertId == 1)].lowestPrice", contains(120_000)))
                    .andExpect(jsonPath("$.content[?(@.concertId == 3)].listingCount", contains(2)))
                    .andExpect(jsonPath("$.content[?(@.concertId == 3)].lowestPrice", contains(90_000)))
                    // 개별 매물은 여기서 주지 않는다.
                    .andExpect(jsonPath("$.content[0].listingId").doesNotExist());
        }

        @Test
        void 매물_목록은_낮은_가격순이고_좌석은_주되_판매자는_내리지_않는다() throws Exception {
            mockMvc.perform(get("/api/v0/market/concerts/{concertId}/listings", 1))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content", hasSize(3)))
                    .andExpect(jsonPath("$.content[0].listingId").value(3))
                    .andExpect(jsonPath("$.content[0].price").value(120_000))
                    .andExpect(jsonPath("$.content[0].faceValue").value(150_000))
                    .andExpect(jsonPath("$.content[0].discountRate").value(20))
                    .andExpect(jsonPath("$.content[0].sectionName").value("1층 B블록"))
                    .andExpect(jsonPath("$.content[0].grade").value("COMMON"))
                    .andExpect(jsonPath("$.content[2].listingId").value(1))
                    .andExpect(jsonPath("$.content[2].discountRate").value(0))
                    .andExpect(jsonPath("$.content[*].mine", everyItem(is(false))))
                    // 좌석번호는 공개한다. 구매자가 자리를 보고 골라야 하기 때문이다.
                    .andExpect(jsonPath("$.content[0].seatNo").exists())
                    .andExpect(jsonPath("$.content[0].seatCol").exists())
                    // 판매자는 어떤 형태로도 드러나면 안 된다.
                    .andExpect(jsonPath("$.content[0].seatId").doesNotExist())
                    .andExpect(jsonPath("$.content[0].sellerAddress").doesNotExist())
                    .andExpect(jsonPath("$.content[0].ticketId").doesNotExist())
                    .andExpect(jsonPath("$.content[0].tokenId").doesNotExist());

            mockMvc.perform(get("/api/v0/market/concerts/{concertId}/listings", 3))
                    .andExpect(jsonPath("$.content", hasSize(2)))
                    .andExpect(jsonPath("$.content[0].listingId").value(5))
                    .andExpect(jsonPath("$.content[0].price").value(90_000));

            // 매물이 없는 공연은 빈 목록이고, 없는 공연은 404 다.
            mockMvc.perform(get("/api/v0/market/concerts/{concertId}/listings", 2))
                    .andExpect(jsonPath("$.content", hasSize(0)));
            mockMvc.perform(get("/api/v0/market/concerts/{concertId}/listings", StubFixtures.NOT_FOUND_ID))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ConcertNotFoundException"));
        }

        @Test
        void 매물_상세는_팔린_뒤에도_조회된다() throws Exception {
            mockMvc.perform(get("/api/v0/market/listings/{listingId}", OTHERS_LISTING_CONCERT1))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.listingId").value(OTHERS_LISTING_CONCERT1))
                    .andExpect(jsonPath("$.status").value("LISTED"))
                    .andExpect(jsonPath("$.concertId").value(1))
                    .andExpect(jsonPath("$.venueName").exists())
                    .andExpect(jsonPath("$.closedAt").doesNotExist())
                    .andExpect(jsonPath("$.seatNo").exists())
                    .andExpect(jsonPath("$.seatCol").exists());

            purchase(OTHERS_LISTING_CONCERT1, 120_000).andExpect(status().isAccepted());

            // 목록에서 상세로 들어가는 사이에 팔릴 수 있어 404 로 감추지 않는다.
            mockMvc.perform(get("/api/v0/market/listings/{listingId}", OTHERS_LISTING_CONCERT1))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("SOLD"))
                    .andExpect(jsonPath("$.closedAt").value("2026-09-10T12:00:00"));
        }

        @Test
        void 구매하면_202와_PENDING_이고_내_거래_내역에_남는다() throws Exception {
            purchase(OTHERS_LISTING_CONCERT1, 120_000)
                    .andExpect(status().isAccepted())
                    .andExpect(jsonPath("$.tradeId").value(1))
                    .andExpect(jsonPath("$.listingId").value(OTHERS_LISTING_CONCERT1))
                    // 온체인 전송이 남아 있어 완료로 적지 않는다.
                    .andExpect(jsonPath("$.status").value("PENDING"))
                    .andExpect(jsonPath("$.price").value(120_000))
                    .andExpect(jsonPath("$.sectionName").value("1층 B블록"))
                    .andExpect(jsonPath("$.tradedAt").value("2026-09-10T12:00:00"))
                    .andExpect(jsonPath("$.txHash").doesNotExist())
                    .andExpect(jsonPath("$.seatNo").exists());

            // 매물에서 사라지고 내 것이 되어 다시 등록할 수 있다.
            mockMvc.perform(get("/api/v0/market/concerts/{concertId}/listings", 1))
                    .andExpect(jsonPath("$.content", hasSize(2)));

            mockMvc.perform(get("/api/v0/market/listings/me"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content", hasSize(1)))
                    .andExpect(jsonPath("$.content[0].type").value("PURCHASE"))
                    .andExpect(jsonPath("$.content[0].status").value("PENDING"))
                    .andExpect(jsonPath("$.content[0].tradeId").value(1))
                    .andExpect(jsonPath("$.content[0].price").value(120_000))
                    .andExpect(jsonPath("$.content[0].occurredAt").value("2026-09-10T12:00:00"));
        }

        @Test
        void 등록은_정가_이하만_되고_취소하면_다시_등록할_수_있다() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TICKET_ID, 99_001)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("ListPriceExceedsFacePriceException"));

            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TICKET_ID, 90_000)))
                    .andExpect(status().isCreated())
                    .andExpect(header().string("Location", "/api/v0/market/listings/6"))
                    .andExpect(jsonPath("$.listingId").value(6))
                    .andExpect(jsonPath("$.status").value("LISTED"))
                    .andExpect(jsonPath("$.faceValue").value(99_000))
                    .andExpect(jsonPath("$.price").value(90_000))
                    .andExpect(jsonPath("$.discountRate").value(9))
                    .andExpect(jsonPath("$.mine").value(true))
                    .andExpect(jsonPath("$.listedAt").value("2026-09-10T12:00:00"));

            mockMvc.perform(get("/api/v0/market/concerts/{concertId}/listings", 3))
                    .andExpect(jsonPath("$.content", hasSize(3)))
                    .andExpect(jsonPath("$.content[?(@.listingId == 6)].mine", everyItem(is(true))));

            // 이미 등록 중인 티켓은 다시 등록할 수 없다.
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TICKET_ID, 80_000)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("TicketNotListableException"));

            // 취소는 행을 지우지 않고 CANCELED 로 남긴다.
            mockMvc.perform(post("/api/v0/market/listings/{listingId}/cancel", 6))
                    .andExpect(status().isNoContent());
            mockMvc.perform(get("/api/v0/market/listings/{listingId}", 6))
                    .andExpect(jsonPath("$.status").value("CANCELED"))
                    .andExpect(jsonPath("$.closedAt").value("2026-09-10T12:00:00"));
            mockMvc.perform(get("/api/v0/market/concerts/{concertId}/listings", 3))
                    .andExpect(jsonPath("$.content", hasSize(2)));

            // 취소했으니 다시 등록되고, 매물 식별자는 새로 생긴다.
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TICKET_ID, 80_000)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.listingId").value(7));
        }

        @Test
        void 내_거래_내역은_판매와_구매를_섞어_최신순으로_준다() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TICKET_ID, 90_000)))
                    .andExpect(status().isCreated());
            purchase(OTHERS_LISTING_CONCERT1, 120_000).andExpect(status().isAccepted());

            mockMvc.perform(get("/api/v0/market/listings/me"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content", hasSize(2)))
                    .andExpect(jsonPath("$.content[?(@.type == 'SALE')].listingId", contains(6)))
                    .andExpect(jsonPath("$.content[?(@.type == 'SALE')].status", contains("LISTED")))
                    .andExpect(jsonPath("$.content[?(@.type == 'SALE')].tradeId", contains(nullValue())))
                    .andExpect(jsonPath("$.content[?(@.type == 'PURCHASE')].status", contains("PENDING")))
                    .andExpect(jsonPath("$.content[0].seatNo").exists())
                    // 거래 상대는 어느 쪽에서도 드러나지 않는다.
                    .andExpect(jsonPath("$.content[0].sellerAddress").doesNotExist());
        }

        @Test
        void 내_매물은_10초_뒤_팔린_것으로_보인다() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TICKET_ID, 90_000)))
                    .andExpect(status().isCreated());

            clock.advance(Duration.ofSeconds(StubFixtures.LISTING_SOLD_AFTER_SECONDS));

            mockMvc.perform(get("/api/v0/market/concerts/{concertId}/listings", 3))
                    .andExpect(jsonPath("$.content", hasSize(2)))
                    .andExpect(jsonPath("$.content[?(@.listingId == 6)]").doesNotExist());

            // 내 판매 내역에는 SOLD 로 남는다.
            mockMvc.perform(get("/api/v0/market/listings/me"))
                    .andExpect(jsonPath("$.content[?(@.type == 'SALE')].status", contains("SOLD")));

            // 팔았으니 내 티켓이 아니다. 다시 등록하려면 403 이다.
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TICKET_ID, 80_000)))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotTicketOwnerException"));
        }

        @Test
        void 남의_티켓_등록_403_남의_매물_취소_403_내_매물_구매_409() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(1L, 100_000)))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotTicketOwnerException"));

            // 매물 취소는 티켓 소유가 아니라 등록자인지를 본다.
            mockMvc.perform(post("/api/v0/market/listings/{listingId}/cancel", OTHERS_LISTING_CONCERT1))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotListingSellerException"));

            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                    .content(listingBody(MY_TICKET_ID, 90_000)));
            purchase(6L, 90_000)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("CannotBuyOwnListingException"));
        }

        @Test
        void 이미_팔린_매물과_가격_불일치는_409() throws Exception {
            purchase(OTHERS_LISTING_CONCERT3, 90_000).andExpect(status().isAccepted());

            // 선착순 경쟁에서 진 쪽. 404 가 아니라 409 다.
            purchase(OTHERS_LISTING_CONCERT3, 90_000)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ListingAlreadyClosedException"));

            // 화면이 들고 있던 가격이 서버와 다르면 거절한다.
            purchase(OTHERS_LISTING_CONCERT1, 119_000)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ListingPriceMismatchException"));
        }

        @Test
        void 예매로_받은_ticketId로_양도_등록이_된다() throws Exception {
            long seatId = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 1);
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId).param("concertId", "1"))
                    .andExpect(status().isOk());

            // 예매 응답이 주는 번호는 둘이다. 주문 번호와 티켓 번호가 다른 값이어야 한다.
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"concertId": 1, "seatId": %d}
                                    """.formatted(seatId)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.id").value(StubFixtures.CREATED_ID_START))
                    .andExpect(jsonPath("$.ticketId").value(StubFixtures.ORDER_TICKET_ID_START));

            // 주문 번호로 등록하면 404 다. 앱이 둘을 혼동하던 것이 양도 등록이 막혀 있던 원인이다.
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(StubFixtures.CREATED_ID_START, 140_000)))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("TicketNotFoundException"));

            // 티켓 번호로 등록하면 통한다. 예매 스텁과 마켓 스텁이 같은 티켓을 본다는 뜻이다.
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(StubFixtures.ORDER_TICKET_ID_START, 140_000)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.status").value("LISTED"))
                    .andExpect(jsonPath("$.price").value(140_000))
                    // 정가는 구역 가격이다. 예매 응답의 facePrice 와 같은 값이어야 앱이 상한을 안내할 수 있다.
                    .andExpect(jsonPath("$.faceValue").value(150_000))
                    .andExpect(jsonPath("$.mine").value(true));

            // 1번 공연 매물이 고정 3개에서 4개로 늘고, 늘어난 것이 내 것이다.
            mockMvc.perform(get("/api/v0/market/concerts/{concertId}/listings", 1))
                    .andExpect(jsonPath("$.content", hasSize(4)))
                    .andExpect(jsonPath("$.content[?(@.mine == true)]", hasSize(1)));
        }

        @Test
        void 등록가는_내_매물만_정가_이하로_고칠_수_있다() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TICKET_ID, 90_000)))
                    .andExpect(status().isCreated());

            // 남의 매물은 고칠 수 없다. 티켓 소유가 아니라 등록자인지를 본다.
            updatePrice(OTHERS_LISTING_CONCERT1, 10_000)
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotListingSellerException"));

            // 정가(구역 가격 99,000)를 넘기면 거절이고 가격은 그대로다.
            updatePrice(6L, 99_001)
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("ListPriceExceedsFacePriceException"));

            updatePrice(6L, 80_000)
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.listingId").value(6))
                    .andExpect(jsonPath("$.price").value(80_000))
                    .andExpect(jsonPath("$.faceValue").value(99_000))
                    .andExpect(jsonPath("$.discountRate").value(19));

            mockMvc.perform(get("/api/v0/market/listings/{listingId}", 6))
                    .andExpect(jsonPath("$.price").value(80_000));

            // 종료된 매물은 고칠 수 없다.
            mockMvc.perform(post("/api/v0/market/listings/{listingId}/cancel", 6))
                    .andExpect(status().isNoContent());
            updatePrice(6L, 70_000)
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ListingAlreadyClosedException"));
        }

        @Test
        void 없는_티켓_없는_매물_필수값_누락은_거절된다() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(StubFixtures.NOT_FOUND_ID, 1000)))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("TicketNotFoundException"));
            purchase(StubFixtures.NOT_FOUND_ID, 1000)
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ListingNotFoundException"));
            mockMvc.perform(post("/api/v0/market/listings/{listingId}/cancel", StubFixtures.NOT_FOUND_ID))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ListingNotFoundException"));
            updatePrice(StubFixtures.NOT_FOUND_ID, 1000)
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ListingNotFoundException"));

            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON).content("{}"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.errors[?(@.field == 'ticketId')]").exists())
                    .andExpect(jsonPath("$.errors[?(@.field == 'price')]").exists());
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TICKET_ID, 0)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.errors[?(@.field == 'price')]").exists());

            // 멱등키가 없으면 구매를 받지 않는다.
            mockMvc.perform(post("/api/v0/market/listings/{listingId}/purchase", OTHERS_LISTING_CONCERT1)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(purchaseBody(120_000)))
                    .andExpect(status().isBadRequest());
        }
    }

    /** 테스트가 앞으로 돌릴 수 있는 시계. 스텁은 {@code LocalDateTime.now(clock)} 만 쓴다. */
    static final class MutableClock extends Clock {

        private Instant now;

        MutableClock(Instant start) {
            this.now = start;
        }

        void advance(Duration duration) {
            now = now.plus(duration);
        }

        @Override
        public ZoneId getZone() {
            return ZoneId.of("Asia/Seoul");
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }

        @Override
        public Instant instant() {
            return now;
        }
    }
}
