package com.ssafy.timo.stub;

import com.ssafy.timo.global.exception.GlobalExceptionHandler;
import com.ssafy.timo.global.storage.PlaceholderImageStorage;
import com.ssafy.timo.stub.concert.ConcertStore;
import com.ssafy.timo.stub.concert.ConcertStubController;
import com.ssafy.timo.stub.reservation.ReservationStubController;
import com.ssafy.timo.stub.seat.SeatStateStore;
import com.ssafy.timo.stub.seat.SeatStubController;
import com.ssafy.timo.stub.seat.SectionStubController;
import com.ssafy.timo.stub.transfer.MarketStubController;
import com.ssafy.timo.stub.venue.VenueStubController;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;

import static org.hamcrest.Matchers.everyItem;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.startsWith;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * v0 스텁 컨트롤러 검증.
 *
 * <p>스프링 컨텍스트를 띄우지 않는 standalone MockMvc 다. 스텁은 DB 도 시큐리티도 필요 없고,
 * {@code IntegrationTest} 컨텍스트에 속성을 덧씌우면 컨텍스트가 하나 더 떠 전체 테스트가 느려진다.
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

    /** 예매 스텁은 주문 뒤 흐른 시간으로 발행 상태를 정하므로 테스트가 시간을 움직일 수 있어야 한다. */
    private final MutableClock clock = new MutableClock(START);

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        SeatStateStore seatStateStore = new SeatStateStore();
        ConcertStore concertStore = new ConcertStore();
        PlaceholderImageStorage imageStorage = new PlaceholderImageStorage("https://cdn.stub.timo.io");
        mockMvc = MockMvcBuilders.standaloneSetup(
                        new VenueStubController(),
                        new ConcertStubController(concertStore, imageStorage),
                        new SectionStubController(seatStateStore),
                        new SeatStubController(seatStateStore, clock),
                        new ReservationStubController(seatStateStore, concertStore, imageStorage, clock),
                        new MarketStubController(concertStore, imageStorage, clock))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
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
            String body = """
                    {
                      "title": "새 공연", "genre": "PLAY", "ageRating": "ALL",
                      "venueId": 1, "artistIds": [1, 1, 2],
                      "posterImageKey": "poster/new.png",
                      "startDate": "2026-12-01T19:00:00", "endDate": "2026-12-02T19:00:00",
                      "openAt": "2026-11-01T20:00:00"
                    }
                    """;
            mockMvc.perform(post("/api/v0/concerts").contentType(MediaType.APPLICATION_JSON).content(body))
                    .andExpect(status().isCreated())
                    .andExpect(header().string("Location", "/api/v0/concerts/" + StubFixtures.CREATED_ID_START))
                    .andExpect(jsonPath("$.status").value("SCHEDULED"))
                    .andExpect(jsonPath("$.viewCount").value(0))
                    .andExpect(jsonPath("$.posterImageUrl").value("https://cdn.stub.timo.io/poster/new.png"))
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
            mockMvc.perform(post("/api/v0/concerts")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("""
                                    {"title": "t", "genre": "PLAY", "ageRating": "ALL", "venueId": 1, "artistIds": [1],
                                     "startDate": "2026-12-02T19:00:00", "endDate": "2026-12-01T19:00:00"}
                                    """))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("InvalidConcertPeriodException"));
        }
    }

    @Nested
    @DisplayName("구역 · 좌석")
    class SeatAndSection {

        @Test
        void 구역_목록은_잔여석_합계를_준다() throws Exception {
            mockMvc.perform(get("/api/v0/sections").param("venueId", "1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.venueId").value(1))
                    .andExpect(jsonPath("$.sections", hasSize(3)))
                    .andExpect(jsonPath("$.sections[0].seatCount").value(5))
                    .andExpect(jsonPath("$.sections[0].availableCount").value(5));
        }

        @Test
        void 구역_합계는_명세_문서의_값과_같다() throws Exception {
            // docs/stub/STUB_SEAT_API.md 의 고정 배치도 표와 맞아야 한다.
            mockMvc.perform(get("/api/v0/sections").param("venueId", "1"))
                    .andExpect(jsonPath("$.totalSeatCount").value(135))
                    .andExpect(jsonPath("$.totalAvailableCount").value(112))
                    .andExpect(jsonPath("$.sections[1].availableCount").value(33))
                    .andExpect(jsonPath("$.sections[2].seatCount").value(90))
                    .andExpect(jsonPath("$.sections[2].availableCount").value(74));
        }

        @Test
        void venueId_없이_부르면_400() throws Exception {
            mockMvc.perform(get("/api/v0/sections"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("MissingServletRequestParameterException"));
        }

        @Test
        void venueId_가_숫자가_아니면_400() throws Exception {
            mockMvc.perform(get("/api/v0/sections").param("venueId", "abc"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("MethodArgumentTypeMismatchException"));
        }

        @Test
        void A블록_좌석은_명세_예시와_같은_5석이다() throws Exception {
            mockMvc.perform(get("/api/v0/seats").param("sectionId", "1"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.rowCount").value(2))
                    .andExpect(jsonPath("$.seatPerRow").value(3))
                    .andExpect(jsonPath("$.seats", hasSize(5)))
                    .andExpect(jsonPath("$.seats[?(@.seatNo == 2 && @.seatCol == 2)]").doesNotExist())
                    .andExpect(jsonPath("$.seats[*].status", everyItem(is("AVAILABLE"))));
        }

        @Test
        void 선점하면_조회에_RESERVED_로_보이고_잔여석이_준다() throws Exception {
            long seatId = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 1);

            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("RESERVED"))
                    .andExpect(jsonPath("$.heldUntil").value("2026-09-10T12:05:00"))
                    .andExpect(jsonPath("$.releasedSeatId").doesNotExist());

            mockMvc.perform(get("/api/v0/seats").param("sectionId", "1"))
                    .andExpect(jsonPath("$.availableCount").value(4))
                    .andExpect(jsonPath("$.seats[0].status").value("RESERVED"));

            mockMvc.perform(get("/api/v0/sections").param("venueId", "1"))
                    .andExpect(jsonPath("$.sections[0].availableCount").value(4));
        }

        @Test
        void 다른_자리를_잡으면_이전_선점이_풀린다() throws Exception {
            long first = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 1);
            long second = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 2);

            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", first)).andExpect(status().isOk());
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", second))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.releasedSeatId").value((int) first));

            mockMvc.perform(get("/api/v0/seats").param("sectionId", "1"))
                    .andExpect(jsonPath("$.seats[0].status").value("AVAILABLE"))
                    .andExpect(jsonPath("$.seats[1].status").value("RESERVED"));
        }

        @Test
        void 선점_점유_해제_흐름이_이어진다() throws Exception {
            long seatId = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 3);

            mockMvc.perform(post("/api/v0/seats/{seatId}/occupancy", seatId))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("SeatNotHeldException"));

            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId)).andExpect(status().isOk());
            mockMvc.perform(post("/api/v0/seats/{seatId}/occupancy", seatId))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("OCCUPIED"));

            mockMvc.perform(delete("/api/v0/seats/{seatId}/hold", seatId))
                    .andExpect(status().isForbidden());

            mockMvc.perform(delete("/api/v0/seats/{seatId}/occupancy", seatId))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("AVAILABLE"));
        }

        @Test
        void 남이_잡은_고정_좌석은_선점_403_취소_403() throws Exception {
            // C블록의 13 번째 자리는 초기 상태가 RESERVED 다. (StubFixtures.initialStatus)
            long seatId = StubFixtures.SECTIONS.get(2).id() * 1_000 + 13;

            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("SeatNotHoldableException"));
            mockMvc.perform(delete("/api/v0/seats/{seatId}/hold", seatId))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("SeatHoldNotOwnedException"));
        }

        @Test
        void 없는_좌석은_404() throws Exception {
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", StubFixtures.NOT_FOUND_ID))
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
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId)).andExpect(status().isOk());
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content(body(concertId, seatId)))
                    .andExpect(status().isCreated());
        }

        @Test
        void 선점한_좌석으로_주문하면_201_PENDING_MINT_이고_좌석은_OCCUPIED_가_된다() throws Exception {
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId)).andExpect(status().isOk());

            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content(body(1, seatId)))
                    .andExpect(status().isCreated())
                    .andExpect(header().string("Location", "/api/v0/reservations/" + StubFixtures.CREATED_ID_START))
                    .andExpect(jsonPath("$.status").value("PENDING_MINT"))
                    .andExpect(jsonPath("$.orderId", startsWith("0x")))
                    .andExpect(jsonPath("$.tokenId").doesNotExist())
                    .andExpect(jsonPath("$.facePrice").value(150000))
                    .andExpect(jsonPath("$.concertTitle").value("김필 단독 콘서트"))
                    .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                    .andExpect(jsonPath("$.mintAttemptCount").value(0));

            mockMvc.perform(get("/api/v0/seats").param("sectionId", "1"))
                    .andExpect(jsonPath("$.seats[0].status").value("OCCUPIED"));
        }

        @Test
        void 시간이_지나면_MINTED_로_바뀌고_tokenId_가_생긴다() throws Exception {
            holdAndReserve(1, seatId);

            clock.advance(Duration.ofSeconds(StubFixtures.MINT_DELAY_SECONDS));

            mockMvc.perform(get("/api/v0/reservations/{id}", StubFixtures.CREATED_ID_START))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("MINTED"))
                    .andExpect(jsonPath("$.tokenId").value(String.valueOf(StubFixtures.CREATED_ID_START)))
                    .andExpect(jsonPath("$.mintTxHash", startsWith("0x")))
                    .andExpect(jsonPath("$.mintAttemptCount").value(1))
                    .andExpect(jsonPath("$.failureReason").doesNotExist());
        }

        @Test
        void 실패_좌석은_MINT_FAILED_를_거쳐_REFUNDED_가_되고_좌석이_풀린다() throws Exception {
            long failSeat = StubFixtures.MINT_FAIL_SEAT_ID;
            holdAndReserve(1, failSeat);

            clock.advance(Duration.ofSeconds(StubFixtures.MINT_DELAY_SECONDS));
            mockMvc.perform(get("/api/v0/reservations/{id}", StubFixtures.CREATED_ID_START))
                    .andExpect(jsonPath("$.status").value("MINT_FAILED"))
                    .andExpect(jsonPath("$.mintAttemptCount").value(3))
                    .andExpect(jsonPath("$.failureReason").value(StubFixtures.MINT_FAILURE_REASON));

            clock.advance(Duration.ofSeconds(StubFixtures.REFUND_DELAY_SECONDS));
            mockMvc.perform(get("/api/v0/reservations/{id}", StubFixtures.CREATED_ID_START))
                    .andExpect(jsonPath("$.status").value("REFUNDED"));

            mockMvc.perform(get("/api/v0/seats").param("sectionId", "1"))
                    .andExpect(jsonPath("$.seats[?(@.id == " + failSeat + ")].status", everyItem(is("AVAILABLE"))));

            // 환불된 주문은 보유가 아니라 같은 공연을 다시 예매할 수 있다.
            holdAndReserve(1, seatId);
        }

        @Test
        void 취소하면_CANCELLED_이고_좌석은_노출되지_않으며_다시_예매할_수_있다() throws Exception {
            holdAndReserve(1, seatId);
            clock.advance(Duration.ofSeconds(StubFixtures.MINT_DELAY_SECONDS));

            mockMvc.perform(delete("/api/v0/reservations/{id}", StubFixtures.CREATED_ID_START))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.status").value("CANCELLED"))
                    .andExpect(jsonPath("$.tokenId").value(String.valueOf(StubFixtures.CREATED_ID_START)))
                    .andExpect(jsonPath("$.updatedAt").value("2026-09-10T12:00:03"));

            // 회수 좌석은 선택 화면에 다시 나오지 않는다.
            mockMvc.perform(get("/api/v0/seats").param("sectionId", "1"))
                    .andExpect(jsonPath("$.seats[0].status").value("OCCUPIED"));
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId)).andExpect(status().isConflict());

            // 취소한 뒤에는 같은 공연을 다시 예매할 수 있다 (다른 좌석).
            holdAndReserve(1, StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 2));

            // 두 번 취소는 409.
            mockMvc.perform(delete("/api/v0/reservations/{id}", StubFixtures.CREATED_ID_START))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ReservationNotCancellableException"));
        }

        @Test
        void 발행_전_주문은_취소_409() throws Exception {
            holdAndReserve(1, seatId);
            mockMvc.perform(delete("/api/v0/reservations/{id}", StubFixtures.CREATED_ID_START))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ReservationNotCancellableException"));
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
            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", seatId));
            mockMvc.perform(post("/api/v0/reservations").contentType(MediaType.APPLICATION_JSON).content(body(2, seatId)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("ConcertNotOnSaleException"));
        }

        @Test
        void 같은_공연을_두_번_예매하면_409() throws Exception {
            long second = StubFixtures.seatId(StubFixtures.SECTIONS.get(0), 1, 2);
            holdAndReserve(1, seatId);

            mockMvc.perform(post("/api/v0/seats/{seatId}/hold", second));
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
            clock.advance(Duration.ofSeconds(StubFixtures.MINT_DELAY_SECONDS));

            mockMvc.perform(get("/api/v0/reservations"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content", hasSize(1)))
                    .andExpect(jsonPath("$.content[0].status").value("MINTED"))
                    .andExpect(jsonPath("$.content[0].tokenId").doesNotExist())
                    .andExpect(jsonPath("$.page.totalElements").value(1));

            mockMvc.perform(get("/api/v0/reservations").param("status", "PENDING_MINT"))
                    .andExpect(jsonPath("$.content", hasSize(0)));
        }
    }

    @Nested
    @DisplayName("양도 마켓")
    class Market {

        /** 내가 처음부터 보유한 티켓. 3번 공연 2층 C블록, 정가 99,000. */
        private static final String MY_TOKEN = StubFixtures.MY_TICKET_TOKEN_ID;

        private String listingBody(String tokenId, long askPrice) {
            return """
                    {"tokenId": "%s", "askPrice": %d}
                    """.formatted(tokenId, askPrice);
        }

        @Test
        void 매물_목록은_낮은_가격순이고_공연으로_걸러진다() throws Exception {
            mockMvc.perform(get("/api/v0/market/listings"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.content", hasSize(5)))
                    .andExpect(jsonPath("$.content[0].tokenId").value("5"))
                    .andExpect(jsonPath("$.content[0].listPrice").value(90_000))
                    .andExpect(jsonPath("$.content[0].discountRate").value(9))
                    .andExpect(jsonPath("$.content[4].tokenId").value("1"))
                    .andExpect(jsonPath("$.content[4].discountRate").value(0))
                    .andExpect(jsonPath("$.content[*].mine", everyItem(is(false))))
                    .andExpect(jsonPath("$.content[0].sellerAddress").value(StubFixtures.OTHER_WALLET_ADDRESS));

            // 내 보유 티켓(101)은 등록 전이라 매물에 없다.
            mockMvc.perform(get("/api/v0/market/listings").param("concertId", "3"))
                    .andExpect(jsonPath("$.content", hasSize(2)))
                    .andExpect(jsonPath("$.content[0].tokenId").value("5"));
            mockMvc.perform(get("/api/v0/market/listings").param("concertId", "1"))
                    .andExpect(jsonPath("$.content", hasSize(3)))
                    .andExpect(jsonPath("$.content[0].tokenId").value("3"));
            mockMvc.perform(get("/api/v0/market/listings").param("concertId", "2"))
                    .andExpect(jsonPath("$.content", hasSize(0)));
        }

        @Test
        void 구매하면_내_것이_되고_매물에서_사라지며_다시_등록할_수_있다() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings/{tokenId}/purchase", "3"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.tradeId", startsWith("0x")))
                    .andExpect(jsonPath("$.txHash", startsWith("0x")))
                    .andExpect(jsonPath("$.tokenId").value("3"))
                    .andExpect(jsonPath("$.price").value(120_000))
                    .andExpect(jsonPath("$.sectionName").value("1층 B블록"))
                    .andExpect(jsonPath("$.purchasedAt").value("2026-09-10T12:00:00"));

            mockMvc.perform(get("/api/v0/market/listings").param("concertId", "1"))
                    .andExpect(jsonPath("$.content", hasSize(2)));

            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody("3", 100_000)))
                    .andExpect(status().isCreated())
                    .andExpect(jsonPath("$.mine").value(true))
                    .andExpect(jsonPath("$.sellerAddress").value(StubFixtures.MY_WALLET_ADDRESS));
        }

        @Test
        void 그_공연_티켓을_보유하면_1인_1매로_구매가_막힌다() throws Exception {
            // 내 티켓 101 이 3번 공연이라 3번 공연 매물은 처음부터 못 산다.
            mockMvc.perform(post("/api/v0/market/listings/{tokenId}/purchase", "5"))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("AlreadyReservedException"));

            // 1번 공연은 살 수 있고, 사고 나면 그 공연의 다른 매물이 막힌다.
            mockMvc.perform(post("/api/v0/market/listings/{tokenId}/purchase", "3")).andExpect(status().isOk());
            mockMvc.perform(post("/api/v0/market/listings/{tokenId}/purchase", "2"))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("AlreadyReservedException"));
        }

        @Test
        void 등록은_정가_이하만_되고_취소하면_다시_등록할_수_있다() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TOKEN, 99_001)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.exception").value("ListPriceExceedsFacePriceException"));

            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TOKEN, 90_000)))
                    .andExpect(status().isCreated())
                    .andExpect(header().string("Location", "/api/v0/market/listings/" + MY_TOKEN))
                    .andExpect(jsonPath("$.facePrice").value(99_000))
                    .andExpect(jsonPath("$.listPrice").value(90_000))
                    .andExpect(jsonPath("$.discountRate").value(9))
                    .andExpect(jsonPath("$.mine").value(true))
                    .andExpect(jsonPath("$.listedAt").value("2026-09-10T12:00:00"));

            mockMvc.perform(get("/api/v0/market/listings").param("concertId", "3"))
                    .andExpect(jsonPath("$.content", hasSize(3)))
                    .andExpect(jsonPath("$.content[?(@.tokenId == '" + MY_TOKEN + "')].mine", everyItem(is(true))));

            // 이미 등록 중인 티켓은 다시 등록할 수 없다.
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TOKEN, 80_000)))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("TicketNotListableException"));

            mockMvc.perform(delete("/api/v0/market/listings/{tokenId}", MY_TOKEN))
                    .andExpect(status().isNoContent());
            mockMvc.perform(get("/api/v0/market/listings").param("concertId", "3"))
                    .andExpect(jsonPath("$.content", hasSize(2)));
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TOKEN, 80_000)))
                    .andExpect(status().isCreated());
        }

        @Test
        void 내_매물은_10초_뒤_팔린_것으로_보인다() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TOKEN, 90_000)))
                    .andExpect(status().isCreated());

            clock.advance(Duration.ofSeconds(StubFixtures.LISTING_SOLD_AFTER_SECONDS));

            mockMvc.perform(get("/api/v0/market/listings").param("concertId", "3"))
                    .andExpect(jsonPath("$.content", hasSize(2)))
                    .andExpect(jsonPath("$.content[?(@.tokenId == '" + MY_TOKEN + "')]").doesNotExist());

            // 팔았으니 내 티켓이 아니다. 다시 등록하려면 403 이고, 그 공연 매물을 살 수 있게 된다.
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TOKEN, 80_000)))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotTicketOwnerException"));
            mockMvc.perform(post("/api/v0/market/listings/{tokenId}/purchase", "5"))
                    .andExpect(status().isOk());
        }

        @Test
        void 남의_티켓_등록_403_남의_매물_취소_403_내_매물_구매_409() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody("1", 100_000)))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotTicketOwnerException"));
            mockMvc.perform(delete("/api/v0/market/listings/{tokenId}", "1"))
                    .andExpect(status().isForbidden())
                    .andExpect(jsonPath("$.exception").value("NotTicketOwnerException"));

            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                    .content(listingBody(MY_TOKEN, 90_000)));
            mockMvc.perform(post("/api/v0/market/listings/{tokenId}/purchase", MY_TOKEN))
                    .andExpect(status().isConflict())
                    .andExpect(jsonPath("$.exception").value("CannotBuyOwnListingException"));
        }

        @Test
        void 없는_티켓_없는_매물_필수값_누락은_거절된다() throws Exception {
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(String.valueOf(StubFixtures.NOT_FOUND_ID), 1000)))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("TicketNotFoundException"));
            mockMvc.perform(post("/api/v0/market/listings/{tokenId}/purchase", StubFixtures.NOT_FOUND_ID))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ListingNotFoundException"));
            // 등록되지 않은 내 티켓은 매물이 아니라 404 다.
            mockMvc.perform(delete("/api/v0/market/listings/{tokenId}", MY_TOKEN))
                    .andExpect(status().isNotFound())
                    .andExpect(jsonPath("$.exception").value("ListingNotFoundException"));

            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON).content("{}"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.errors[?(@.field == 'tokenId')]").exists())
                    .andExpect(jsonPath("$.errors[?(@.field == 'askPrice')]").exists());
            mockMvc.perform(post("/api/v0/market/listings").contentType(MediaType.APPLICATION_JSON)
                            .content(listingBody(MY_TOKEN, 0)))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.errors[?(@.field == 'askPrice')]").exists());
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
