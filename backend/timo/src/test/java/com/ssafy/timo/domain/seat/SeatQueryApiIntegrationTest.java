package com.ssafy.timo.domain.seat;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 구역·좌석 조회 API 통합 테스트.
 *
 * <p>잔여석 집계는 group by 로 한 번에 모으고, 남은 자리가 없는 구역은 결과에 아예 나오지 않아
 * 읽는 쪽에서 0 으로 채운다. 이런 동작은 실제 DB 를 태워야 드러나므로 운영과 같은 MySQL 을 쓴다.
 *
 * <p>선행 데이터는 매 테스트 시작 시 리포지토리로 직접 넣는다. {@code @IntegrationTest} 가
 * 트랜잭션을 걸어 두므로 테스트가 끝나면 롤백되어 서로 영향을 주지 않는다.
 */
@IntegrationTest
class SeatQueryApiIntegrationTest {

    private static final String SECTION_PATH = "/api/v1/sections";
    private static final String SEAT_PATH = "/api/v1/seats";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private EntityManager em;

    private Long venueId;
    private Long concertId;
    private Long buyerId;

    @BeforeEach
    void setUpFixtures() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());
        venueId = venue.getId();

        // 좌석 상태는 공연 기준으로 유도되므로 조회에도 공연이 필요하다.
        concertId = concertRepository.save(Concert.builder()
                .title("9월 20일 공연")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.now().plusDays(20))
                .endDate(LocalDateTime.now().plusDays(20).plusHours(3))
                .openAt(LocalDateTime.now().plusDays(10))
                .venue(venue)
                .build()).getId();

        buyerId = memberRepository.save(Member.builder()
                .phoneNumber("01011112222")
                .name("전재민")
                .nickname("구매자")
                .build()).getId();
    }

    // ---------------------------------------------------------------- 구역 목록

    @Test
    @DisplayName("공연장의 구역을 잔여석과 함께 등록 순서로 돌려준다")
    void findSections_returnsSectionsWithAvailableCount() throws Exception {
        saveSection("1층 A블록", 150000, 3, 2);
        saveSection("2층 B블록", 90000, 2, 2);
        flushAndClear();

        mvc.perform(get(SECTION_PATH).param("concertId", String.valueOf(concertId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.venueId").value(venueId.intValue()))
                .andExpect(jsonPath("$.venueName").value("고척돔"))
                .andExpect(jsonPath("$.totalSeatCount").value(10))
                .andExpect(jsonPath("$.totalAvailableCount").value(10))
                .andExpect(jsonPath("$.sections.length()").value(2))
                .andExpect(jsonPath("$.sections[0].name").value("1층 A블록"))
                .andExpect(jsonPath("$.sections[0].grade").value("COMMON"))
                .andExpect(jsonPath("$.sections[0].price").value(150000))
                .andExpect(jsonPath("$.sections[0].seatCount").value(6))
                .andExpect(jsonPath("$.sections[0].availableCount").value(6))
                .andExpect(jsonPath("$.sections[0].rowCount").value(3))
                .andExpect(jsonPath("$.sections[0].seatPerRow").value(2))
                .andExpect(jsonPath("$.sections[1].name").value("2층 B블록"));
    }

    @Test
    @DisplayName("구역 목록에는 개별 좌석을 담지 않는다")
    void findSections_omitsIndividualSeats() throws Exception {
        saveSection("1층 A블록", 150000, 3, 2);
        flushAndClear();

        mvc.perform(get(SECTION_PATH).param("concertId", String.valueOf(concertId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections[0].seats").doesNotExist());
    }

    @Test
    @DisplayName("팔린 좌석은 잔여석에서 빠진다")
    void findSections_excludesSoldSeatsFromAvailableCount() throws Exception {
        Section section = saveSection("1층 A블록", 150000, 3, 2);
        occupyFirstSeats(section, 2);
        flushAndClear();

        mvc.perform(get(SECTION_PATH).param("concertId", String.valueOf(concertId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections[0].seatCount").value(6))
                .andExpect(jsonPath("$.sections[0].availableCount").value(4))
                .andExpect(jsonPath("$.totalAvailableCount").value(4));
    }

    @Test
    @DisplayName("전석이 팔린 구역도 잔여석 0 으로 목록에 남는다")
    void findSections_keepsSoldOutSectionWithZeroAvailable() throws Exception {
        Section soldOut = saveSection("1층 A블록", 150000, 3, 2);
        saveSection("2층 B블록", 90000, 2, 2);
        occupyFirstSeats(soldOut, 6);
        flushAndClear();

        // group by 결과에 이 구역이 없다고 목록에서 빠지면, 매진 구역이 화면에서 사라진다.
        mvc.perform(get(SECTION_PATH).param("concertId", String.valueOf(concertId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections.length()").value(2))
                .andExpect(jsonPath("$.sections[0].name").value("1층 A블록"))
                .andExpect(jsonPath("$.sections[0].seatCount").value(6))
                .andExpect(jsonPath("$.sections[0].availableCount").value(0))
                .andExpect(jsonPath("$.totalAvailableCount").value(4));
    }

    @Test
    @DisplayName("좌석을 아직 등록하지 않은 공연장은 200 과 빈 구역 목록을 돌려준다")
    void findSections_returnsEmptyListWhenNoSectionRegistered() throws Exception {
        mvc.perform(get(SECTION_PATH).param("concertId", String.valueOf(concertId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections.length()").value(0))
                .andExpect(jsonPath("$.totalSeatCount").value(0))
                .andExpect(jsonPath("$.totalAvailableCount").value(0));
    }

    @Test
    @DisplayName("다른 공연장의 구역은 섞이지 않는다")
    void findSections_doesNotLeakOtherVenueSections() throws Exception {
        saveSection("1층 A블록", 150000, 3, 2);

        Venue other = venueRepository.save(Venue.builder()
                .name("체조경기장")
                .address("서울시 송파구")
                .totalSeatCount(10000)
                .build());
        saveSectionIn(other, "남의 구역", 50000, 2, 2);
        flushAndClear();

        mvc.perform(get(SECTION_PATH).param("concertId", String.valueOf(concertId)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sections.length()").value(1))
                .andExpect(jsonPath("$.sections[0].name").value("1층 A블록"));
    }

    @Test
    @DisplayName("존재하지 않는 공연이면 404 를 반환한다")
    void findSections_returnsNotFoundWhenConcertMissing() throws Exception {
        long missingConcertId = concertId + 1_000L;

        mvc.perform(get(SECTION_PATH).param("concertId", String.valueOf(missingConcertId)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 공연입니다. (concertId=" + missingConcertId + ")"))
                .andExpect(jsonPath("$.exception").value("ConcertNotFoundException"));
    }

    @Test
    @DisplayName("concertId 를 주지 않으면 400 을 반환한다")
    void findSections_rejectsMissingConcertId() throws Exception {
        mvc.perform(get(SECTION_PATH))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception")
                        .value("MissingServletRequestParameterException"));
    }

    // ---------------------------------------------------------------- 구역 좌석 목록

    @Test
    @DisplayName("구역의 좌석을 배치도 순서(행 -> 자리)로 돌려준다")
    void findSeats_returnsSeatsInLayoutOrder() throws Exception {
        // 일부러 뒤죽박죽 순서로 저장해, 응답 순서가 저장 순서가 아니라 정렬 결과임을 확인한다.
        Section section = saveSectionWithPositions("1층 A블록", 150000, 2, 3,
                List.of(new SeatPosition(2, 3), new SeatPosition(1, 2),
                        new SeatPosition(2, 1), new SeatPosition(1, 1)));
        flushAndClear();

        mvc.perform(get(SEAT_PATH).param("concertId", String.valueOf(concertId)).param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats.length()").value(4))
                .andExpect(jsonPath("$.seats[0].seatNo").value(1))
                .andExpect(jsonPath("$.seats[0].seatCol").value(1))
                .andExpect(jsonPath("$.seats[1].seatNo").value(1))
                .andExpect(jsonPath("$.seats[1].seatCol").value(2))
                .andExpect(jsonPath("$.seats[2].seatNo").value(2))
                .andExpect(jsonPath("$.seats[2].seatCol").value(1))
                .andExpect(jsonPath("$.seats[3].seatNo").value(2))
                .andExpect(jsonPath("$.seats[3].seatCol").value(3));
    }

    @Test
    @DisplayName("등급과 가격은 좌석마다가 아니라 응답 머리에 한 번만 담긴다")
    void findSeats_putsGradeAndPriceOnceAtTheTop() throws Exception {
        Section section = saveSection("1층 A블록", 150000, 2, 2);
        flushAndClear();

        mvc.perform(get(SEAT_PATH).param("concertId", String.valueOf(concertId)).param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.sectionId").value(section.getId().intValue()))
                .andExpect(jsonPath("$.sectionName").value("1층 A블록"))
                .andExpect(jsonPath("$.grade").value("COMMON"))
                .andExpect(jsonPath("$.price").value(150000))
                .andExpect(jsonPath("$.rowCount").value(2))
                .andExpect(jsonPath("$.seatPerRow").value(2))
                .andExpect(jsonPath("$.seats[0].grade").doesNotExist())
                .andExpect(jsonPath("$.seats[0].price").doesNotExist())
                .andExpect(jsonPath("$.seats[0].sectionId").doesNotExist());
    }

    @Test
    @DisplayName("좌석마다 상태가 담기고 잔여석이 함께 계산된다")
    void findSeats_returnsStatusPerSeatWithAvailableCount() throws Exception {
        Section section = saveSection("1층 A블록", 150000, 2, 2);
        occupyFirstSeats(section, 1);
        flushAndClear();

        mvc.perform(get(SEAT_PATH).param("concertId", String.valueOf(concertId)).param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seatCount").value(4))
                .andExpect(jsonPath("$.availableCount").value(3))
                .andExpect(jsonPath("$.seats[0].status").value("SOLD"))
                .andExpect(jsonPath("$.seats[1].status").value("AVAILABLE"));
    }

    @Test
    @DisplayName("좌석 응답에 파생 필드가 새어 나오지 않는다")
    void findSeats_doesNotLeakDerivedFields() throws Exception {
        Section section = saveSection("1층 A블록", 150000, 2, 2);
        flushAndClear();

        // status 로 잔여석을 세는 헬퍼가 getter 모양이면 available 필드가 딸려 나간다.
        mvc.perform(get(SEAT_PATH).param("concertId", String.valueOf(concertId)).param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats[0].available").doesNotExist())
                .andExpect(jsonPath("$.seats[0].section").doesNotExist());
    }

    @Test
    @DisplayName("다른 구역의 좌석은 섞이지 않는다")
    void findSeats_doesNotLeakOtherSectionSeats() throws Exception {
        Section target = saveSection("1층 A블록", 150000, 2, 2);
        saveSection("2층 B블록", 90000, 3, 3);
        flushAndClear();

        mvc.perform(get(SEAT_PATH).param("concertId", String.valueOf(concertId)).param("sectionId", String.valueOf(target.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats.length()").value(4));
    }

    @Test
    @DisplayName("존재하지 않는 구역이면 404 를 반환한다")
    void findSeats_returnsNotFoundWhenSectionMissing() throws Exception {
        long missingSectionId = 999_999L;

        mvc.perform(get(SEAT_PATH).param("concertId", String.valueOf(concertId)).param("sectionId", String.valueOf(missingSectionId)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.errorMessage")
                        .value("존재하지 않는 구역입니다. (sectionId=" + missingSectionId + ")"))
                .andExpect(jsonPath("$.exception").value("SectionNotFoundException"));
    }

    @Test
    @DisplayName("sectionId 를 주지 않으면 400 을 반환한다")
    void findSeats_rejectsMissingSectionId() throws Exception {
        mvc.perform(get(SEAT_PATH))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception")
                        .value("MissingServletRequestParameterException"));
    }

    @Test
    @DisplayName("sectionId 가 숫자가 아니면 400 을 반환한다")
    void findSeats_rejectsNonNumericSectionId() throws Exception {
        mvc.perform(get(SEAT_PATH).param("concertId", String.valueOf(concertId)).param("sectionId", "abc"))
                .andExpect(status().isBadRequest());
    }

    // ---------------------------------------------------------------- 헬퍼

    private Section saveSection(String name, int price, int rowCount, int seatPerRow) {
        return saveSectionIn(venueRepository.getReferenceById(venueId), name, price, rowCount, seatPerRow);
    }

    private Section saveSectionIn(Venue venue, String name, int price, int rowCount, int seatPerRow) {
        List<SeatPosition> positions = allPositions(rowCount, seatPerRow);
        return saveSectionIn(venue, name, price, rowCount, seatPerRow, positions);
    }

    private Section saveSectionWithPositions(String name, int price, int rowCount, int seatPerRow,
                                             List<SeatPosition> positions) {
        return saveSectionIn(venueRepository.getReferenceById(venueId),
                name, price, rowCount, seatPerRow, positions);
    }

    private Section saveSectionIn(Venue venue, String name, int price, int rowCount, int seatPerRow,
                                  List<SeatPosition> positions) {
        Section section = sectionRepository.save(Section.builder()
                .name(name)
                .price(price)
                .rowCount(rowCount)
                .seatPerRow(seatPerRow)
                .venue(venue)
                .build());

        seatRepository.saveAll(section.createSeats(positions));
        return section;
    }

    private List<SeatPosition> allPositions(int rowCount, int seatPerRow) {
        return java.util.stream.IntStream.rangeClosed(1, rowCount)
                .boxed()
                .flatMap(row -> java.util.stream.IntStream.rangeClosed(1, seatPerRow)
                        .mapToObj(col -> new SeatPosition(row, col)))
                .toList();
    }

    /**
     * 앞에서부터 좌석 몇 개를 이 공연에서 판매 완료로 만든다.
     *
     * <p>좌석 행이 아니라 주문 행을 넣는다. 판매 상태는 이제 좌석이 아니라 {@code reservation} 이
     * 갖기 때문이다. 주문 확정 API 가 아직 없어 행을 직접 만든다.
     *
     * <p>구매자를 좌석마다 새로 만든다. {@code uk_rsv_member} 가 한 공연에서 회원당 한 건만
     * 허용하므로 같은 회원으로 여러 자리를 살 수 없다.
     */
    private void occupyFirstSeats(Section section, int count) {
        List<Seat> seats = seatRepository
                .findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId())
                .subList(0, count);

        Concert concert = concertRepository.getReferenceById(concertId);
        for (int i = 0; i < seats.size(); i++) {
            Member buyer = i == 0
                    ? memberRepository.getReferenceById(buyerId)
                    : memberRepository.save(Member.builder()
                            .phoneNumber("0102222" + String.format("%04d", i))
                            .name("전재민")
                            .nickname("구매자" + section.getId() + "-" + i)
                            .build());

            reservationRepository.save(Reservation.builder()
                    .concert(concert)
                    .member(buyer)
                    .seat(seats.get(i))
                    .build());
        }
    }

    /**
     * 방금 저장한 내용을 DB 까지 밀어 넣고 영속성 컨텍스트를 비운다.
     *
     * <p>테스트와 요청 처리가 같은 트랜잭션을 쓰므로, 비우지 않으면 캐시된 인스턴스가 그대로 돌아와
     * 실제 쿼리의 정렬·집계가 검증되지 않는다.
     */
    private void flushAndClear() {
        em.flush();
        em.clear();
    }
}
