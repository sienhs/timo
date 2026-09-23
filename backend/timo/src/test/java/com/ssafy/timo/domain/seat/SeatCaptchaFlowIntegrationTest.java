package com.ssafy.timo.domain.seat;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import com.ssafy.timo.domain.captcha.client.StubCaptchaClient;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.config.cache.CacheConfig;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.CacheManager;
import org.springframework.http.MediaType;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;

/**
 * 캡차가 좌석 조회 앞단을 실제로 막는지, 흐름 전체(발급 -> 검증 -> 좌석 조회 -> 선점)로 확인한다.
 *
 * <p>대기열 입장은 이 흐름에서 뺐다. {@code WaitingQueueServiceImpl} 은 Redis 가 있어야 하는데,
 * {@code docker-compose}·{@code application-test.yml} 모두 Redis 를 주석 처리해 뒀고
 * ({@code CacheConfig} B5 진행 메모 참고) 이 저장소에 대기열 통합 테스트가 하나도 없는 것도 같은
 * 이유다. 코드상 실제 순서도 {@code docs/BE_CAPTCHA_TASK_BREAKDOWN.md} 0-3 대로
 * "인증 -> 캡차 -> 비즈니스" 다 - 대기열 입장 검증(admission) 은 아직 어디서도 확인하지 않는다.
 *
 * <p>네이버는 부르지 않는다. {@code test} 프로파일의 {@link StubCaptchaClient} 정답은 고정이다.
 */
@IntegrationTest
class SeatCaptchaFlowIntegrationTest {

    private static final String CAPTCHA_PATH = "/api/v1/captcha";
    private static final String CAPTCHA_VERIFY_PATH = "/api/v1/captcha/verify";
    private static final String SEAT_PATH = "/api/v1/seats";

    @Autowired
    private MockMvc mvc;
    @Autowired
    private VenueRepository venueRepository;
    @Autowired
    private ConcertRepository concertRepository;
    @Autowired
    private SectionRepository sectionRepository;
    @Autowired
    private SeatRepository seatRepository;
    @Autowired
    private MemberRepository memberRepository;
    @Autowired
    private CacheManager cacheManager;
    @Autowired
    private EntityManager em;

    private Venue venue;
    private Concert concert;
    private Section section;
    private Long me;

    @BeforeEach
    void setUpFixtures() {
        venue = venueRepository.save(Venue.builder()
                .name("고척돔").address("서울시 구로구 경인로 430").totalSeatCount(16000).build());

        concert = concertRepository.save(Concert.builder()
                .title("9월 20일 공연")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.now().plusDays(20))
                .endDate(LocalDateTime.now().plusDays(20).plusHours(3))
                // 선점은 openAt <= now < startDate - 2h 안에서만 성립한다. 오픈은 이미 지났어야 한다.
                .openAt(LocalDateTime.now().minusDays(1))
                .venue(venue)
                .build());
        // 등록 직후는 SCHEDULED 라 선점이 전부 막힌다.
        ReflectionTestUtils.setField(concert, "status", ConcertStatus.ON_SALE);

        section = saveSection("1층 A블록", 150000, 2, 2);
        me = saveMember("01011112222", "나").getId();
        flushAndClear();

        Authenticated.set(me);
    }

    @AfterEach
    void tearDown() {
        cacheManager.getCache(CacheConfig.CAPTCHA_KEYS).clear();
        cacheManager.getCache(CacheConfig.CAPTCHA_PASSED).clear();
        cacheManager.getCache(CacheConfig.CAPTCHA_RATES).clear();
        Authenticated.clear();
    }

    @Test
    @DisplayName("발급 -> 검증 -> 좌석 조회 -> 선점 순서로 전부 통과한다")
    void issueVerifyQueryHold_allSucceed() throws Exception {
        String captchaKey = issueCaptcha();

        mvc.perform(post(CAPTCHA_VERIFY_PATH)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(verifyBody(concert.getId(), captchaKey, StubCaptchaClient.ANSWER)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.expiresIn").isNumber());

        mvc.perform(get(SEAT_PATH)
                        .param("concertId", String.valueOf(concert.getId()))
                        .param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.seats.length()").value(4));

        Long seatId = seatIdAt(1, 1);
        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", seatId)
                        .param("concertId", String.valueOf(concert.getId())))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("캡차 없이 좌석 선점을 바로 호출해도 캡차 때문에 막히지는 않는다 - 캡차는 조회에만 건다")
    void hold_isNotBlockedByCaptcha() throws Exception {
        // 발급도 검증도 하지 않는다 - 통과 기록이 전혀 없는 상태다.
        Long seatId = seatIdAt(1, 1);

        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", seatId)
                        .param("concertId", String.valueOf(concert.getId())))
                .andExpect(status().isOk());
    }

    @Test
    @DisplayName("선점 실패(이미 선점됨) 후에도 통과 기록은 유지된다")
    void failedHold_doesNotClearCaptchaPass() throws Exception {
        Long seatId = seatIdAt(1, 1);
        Long other = saveMember("01033334444", "남").getId();
        flushAndClear();

        // 남이 먼저 잡아 둔다 - 캡차와 무관한 준비 단계라 통과 절차를 거치지 않는다.
        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", seatId)
                        .param("concertId", String.valueOf(concert.getId()))
                        .with(Authenticated.as(other)))
                .andExpect(status().isOk());
        flushAndClear();
        Authenticated.set(me);

        String captchaKey = issueCaptcha();
        mvc.perform(post(CAPTCHA_VERIFY_PATH)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(verifyBody(concert.getId(), captchaKey, StubCaptchaClient.ANSWER)))
                .andExpect(status().isOk());

        // 이미 남이 잡은 자리라 409 다.
        mvc.perform(post(SEAT_PATH + "/{seatId}/hold", seatId)
                        .param("concertId", String.valueOf(concert.getId())))
                .andExpect(status().isConflict());

        // 선점은 실패했지만 캡차 통과 기록은 그대로라 조회는 여전히 200 이어야 한다.
        mvc.perform(get(SEAT_PATH)
                        .param("concertId", String.valueOf(concert.getId()))
                        .param("sectionId", String.valueOf(section.getId())))
                .andExpect(status().isOk());
    }

    private String issueCaptcha() throws Exception {
        MvcResult result = mvc.perform(post(CAPTCHA_PATH))
                .andExpect(status().isOk())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.captchaKey");
    }

    private String verifyBody(Long concertId, String captchaKey, String value) {
        return """
                {
                  "concertId": %d,
                  "captchaKey": "%s",
                  "value": "%s"
                }
                """.formatted(concertId, captchaKey, value);
    }

    private Section saveSection(String name, int price, int rowCount, int seatPerRow) {
        List<SeatPosition> positions = IntStream.rangeClosed(1, rowCount)
                .boxed()
                .flatMap(row -> IntStream.rangeClosed(1, seatPerRow)
                        .mapToObj(col -> new SeatPosition(row, col)))
                .toList();

        Section saved = sectionRepository.save(Section.builder()
                .name(name)
                .price(price)
                .rowCount(rowCount)
                .seatPerRow(seatPerRow)
                .venue(venue)
                .build());

        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }

    private Long seatIdAt(int seatNo, int seatCol) {
        return seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId()).stream()
                .filter(seat -> seat.getSeatNo() == seatNo && seat.getSeatCol() == seatCol)
                .findFirst()
                .orElseThrow()
                .getId();
    }

    private Member saveMember(String phoneNumber, String nickname) {
        return memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber)
                .name("전재민")
                .nickname(nickname)
                .build());
    }

    private void flushAndClear() {
        em.flush();
        em.clear();
    }
}
