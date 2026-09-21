package com.ssafy.timo.domain.alarm;

import com.ssafy.timo.domain.alarm.entity.AlarmType;
import com.ssafy.timo.domain.alarm.entity.ConcertAlarm;
import com.ssafy.timo.domain.alarm.repository.ConcertAlarmRepository;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.contains;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 공연 알림 신청 API 통합 테스트.
 *
 * <p>여기서만 확인되는 것은 <b>멱등성</b>과 <b>종류의 독립</b>이다. 신청을 두 번 해도 한 행이어야 하고,
 * 해제는 없던 신청에도 204 여야 하며, 한 종류를 풀어도 같은 공연의 다른 종류는 남아야 한다.
 */
@IntegrationTest
class AlarmApiIntegrationTest {

    private static final String ALARMS_PATH = "/api/v1/alarms";
    private static final String OPEN = "CONCERT_OPEN";
    private static final String MARKET = "MARKET_LISTING";

    @Autowired
    private MockMvc mvc;
    @Autowired
    private VenueRepository venueRepository;
    @Autowired
    private ConcertRepository concertRepository;
    @Autowired
    private MemberRepository memberRepository;
    @Autowired
    private ConcertAlarmRepository concertAlarmRepository;
    @Autowired
    private EntityManager em;

    private Member me;
    private Member other;
    private Concert first;
    private Concert second;

    @BeforeEach
    void setUp() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔").address("서울시 구로구 경인로 430").totalSeatCount(16000).build());
        first = saveConcert(venue, "첫 공연");
        second = saveConcert(venue, "둘째 공연");
        me = saveMember("01011112222", "나");
        other = saveMember("01033334444", "남");
        em.flush();
        Authenticated.set(me.getId());
    }

    @AfterEach
    void clear() {
        Authenticated.clear();
    }

    @Test
    @DisplayName("신청하면 204 이고 그 종류의 내 목록에 공연 요약이 실린다")
    void addAndList() throws Exception {
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN))
                .andExpect(status().isNoContent());

        mvc.perform(get(ALARMS_PATH + "/me").param("type", OPEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].id").value(first.getId()))
                .andExpect(jsonPath("$.content[0].title").value("첫 공연"))
                .andExpect(jsonPath("$.content[0].venueName").value("고척돔"))
                .andExpect(jsonPath("$.content[0].startDate").exists());
    }

    @Test
    @DisplayName("두 번 신청해도 한 행이다 - 연타와 재시도가 안전해야 한다")
    void addIsIdempotent() throws Exception {
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());

        mvc.perform(get(ALARMS_PATH + "/me").param("type", OPEN))
                .andExpect(jsonPath("$.page.totalElements").value(1));
    }

    @Test
    @DisplayName("풀면 204 이고 목록에서 빠진다. 없던 신청을 풀어도 204")
    void removeIsIdempotent() throws Exception {
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());

        mvc.perform(delete(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());
        mvc.perform(delete(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());

        mvc.perform(get(ALARMS_PATH + "/me").param("type", OPEN))
                .andExpect(jsonPath("$.page.totalElements").value(0));
    }

    @Test
    @DisplayName("종류는 서로 독립이다 - 한 종류를 풀어도 같은 공연의 다른 종류는 남는다")
    void typesAreIndependent() throws Exception {
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), MARKET)).andExpect(status().isNoContent());

        mvc.perform(delete(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());

        mvc.perform(get(ALARMS_PATH + "/me").param("type", OPEN))
                .andExpect(jsonPath("$.page.totalElements").value(0));
        mvc.perform(get(ALARMS_PATH + "/me").param("type", MARKET))
                .andExpect(jsonPath("$.page.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].id").value(first.getId()));
    }

    @Test
    @DisplayName("신청한 것이 없으면 상태는 종류마다 false 다")
    void status_noAlarms_allFalse() throws Exception {
        mvc.perform(get(ALARMS_PATH + "/{concertId}", first.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.concertOpen").value(false))
                .andExpect(jsonPath("$.marketListing").value(false));
    }

    @Test
    @DisplayName("신청한 종류만 true 이고 해제하면 다시 false 다")
    void status_reflectsEachTypeIndependently() throws Exception {
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());

        mvc.perform(get(ALARMS_PATH + "/{concertId}", first.getId()))
                .andExpect(jsonPath("$.concertOpen").value(true))
                .andExpect(jsonPath("$.marketListing").value(false));

        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), MARKET)).andExpect(status().isNoContent());
        mvc.perform(delete(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());

        mvc.perform(get(ALARMS_PATH + "/{concertId}", first.getId()))
                .andExpect(jsonPath("$.concertOpen").value(false))
                .andExpect(jsonPath("$.marketListing").value(true));
    }

    @Test
    @DisplayName("상태는 그 공연 것만이고 남의 신청은 섞이지 않는다")
    void status_isPerConcertAndPerMember() throws Exception {
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());
        concertAlarmRepository.saveAndFlush(
                ConcertAlarm.builder().member(other).concert(second).type(AlarmType.MARKET_LISTING).build());

        mvc.perform(get(ALARMS_PATH + "/{concertId}", second.getId()))
                .andExpect(jsonPath("$.concertOpen").value(false))
                .andExpect(jsonPath("$.marketListing").value(false));
    }

    @Test
    @DisplayName("없는 공연의 상태는 404 가 아니라 둘 다 false 다")
    void status_unknownConcert_allFalse() throws Exception {
        mvc.perform(get(ALARMS_PATH + "/{concertId}", 999_999L))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.concertOpen").value(false))
                .andExpect(jsonPath("$.marketListing").value(false));
    }

    @Test
    @DisplayName("me 경로는 상태 조회와 겹치지 않는다")
    void statusPathDoesNotShadowMe() throws Exception {
        mvc.perform(get(ALARMS_PATH + "/me").param("type", OPEN))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page.totalElements").value(0));
    }

    @Test
    @DisplayName("없는 공연을 신청하면 404")
    void unknownConcert() throws Exception {
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", 999_999L, OPEN))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.exception").value("ConcertNotFoundException"));
    }

    @Test
    @DisplayName("없는 종류로 신청하면 400 이고 아무것도 저장되지 않는다")
    void unknownType() throws Exception {
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), "NOPE"))
                .andExpect(status().isBadRequest());

        assertThat(concertAlarmRepository.count()).isZero();
    }

    @Test
    @DisplayName("목록에 종류가 없으면 400")
    void listRequiresType() throws Exception {
        mvc.perform(get(ALARMS_PATH + "/me"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("최근 신청한 순이고 남의 신청은 섞이지 않는다")
    void newestFirstAndMineOnly() throws Exception {
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", first.getId(), OPEN)).andExpect(status().isNoContent());
        mvc.perform(put(ALARMS_PATH + "/{concertId}/{type}", second.getId(), OPEN)).andExpect(status().isNoContent());
        concertAlarmRepository.saveAndFlush(
                ConcertAlarm.builder().member(other).concert(first).type(AlarmType.CONCERT_OPEN).build());

        mvc.perform(get(ALARMS_PATH + "/me").param("type", OPEN))
                .andExpect(jsonPath("$.page.totalElements").value(2))
                .andExpect(jsonPath("$.content[*].id").value(contains(
                        second.getId().intValue(), first.getId().intValue())));
    }

    @Test
    @DisplayName("size 상한은 100")
    void sizeLimit() throws Exception {
        mvc.perform(get(ALARMS_PATH + "/me").param("type", OPEN).param("size", "101"))
                .andExpect(status().isBadRequest());
    }

    private Concert saveConcert(Venue venue, String title) {
        return concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.now().plusDays(30))
                .endDate(LocalDateTime.now().plusDays(30).plusHours(3))
                .openAt(LocalDateTime.now().plusDays(1))
                .venue(venue)
                .build());
    }

    private Member saveMember(String phoneNumber, String nickname) {
        return memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber).name("정희성").nickname(nickname).build());
    }
}
