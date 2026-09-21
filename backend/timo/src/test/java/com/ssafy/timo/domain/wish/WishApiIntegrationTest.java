package com.ssafy.timo.domain.wish;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.domain.wish.entity.ConcertWish;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;

import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.contains;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * 공연 찜 API 통합 테스트.
 *
 * <p>여기서만 확인되는 것은 <b>멱등성</b>과 <b>제약이 스키마에 실제로 걸려 있는지</b>다. 등록을 두 번
 * 해도 한 행이어야 하고, 해제는 없던 찜에도 204 여야 한다. 유니크 제약은 서비스가 삼키므로 API 로는
 * 보이지 않아 저장소로 직접 확인한다.
 */
@IntegrationTest
class WishApiIntegrationTest {

    private static final String WISHES_PATH = "/api/v1/wishes";

    @Autowired
    private MockMvc mvc;
    @Autowired
    private VenueRepository venueRepository;
    @Autowired
    private ConcertRepository concertRepository;
    @Autowired
    private MemberRepository memberRepository;
    @Autowired
    private ConcertWishRepository concertWishRepository;
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
    @DisplayName("찜하면 204 이고 내 목록에 공연 요약이 실린다")
    void addAndList() throws Exception {
        mvc.perform(put(WISHES_PATH + "/{concertId}", first.getId()))
                .andExpect(status().isNoContent());

        mvc.perform(get(WISHES_PATH + "/me"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.page.totalElements").value(1))
                .andExpect(jsonPath("$.content[0].id").value(first.getId()))
                .andExpect(jsonPath("$.content[0].title").value("첫 공연"))
                .andExpect(jsonPath("$.content[0].venueName").value("고척돔"))
                .andExpect(jsonPath("$.content[0].startDate").exists());
    }

    @Test
    @DisplayName("두 번 찜해도 한 행이다 - 하트 연타와 재시도가 안전해야 한다")
    void addIsIdempotent() throws Exception {
        mvc.perform(put(WISHES_PATH + "/{concertId}", first.getId())).andExpect(status().isNoContent());
        mvc.perform(put(WISHES_PATH + "/{concertId}", first.getId())).andExpect(status().isNoContent());

        mvc.perform(get(WISHES_PATH + "/me"))
                .andExpect(jsonPath("$.page.totalElements").value(1));
    }

    @Test
    @DisplayName("풀면 204 이고 목록에서 빠진다. 없던 찜을 풀어도 204")
    void removeIsIdempotent() throws Exception {
        mvc.perform(put(WISHES_PATH + "/{concertId}", first.getId())).andExpect(status().isNoContent());

        mvc.perform(delete(WISHES_PATH + "/{concertId}", first.getId())).andExpect(status().isNoContent());
        mvc.perform(delete(WISHES_PATH + "/{concertId}", first.getId())).andExpect(status().isNoContent());

        mvc.perform(get(WISHES_PATH + "/me"))
                .andExpect(jsonPath("$.page.totalElements").value(0));
    }

    @Test
    @DisplayName("없는 공연을 찜하면 404")
    void unknownConcert() throws Exception {
        mvc.perform(put(WISHES_PATH + "/{concertId}", 999_999L))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.exception").value("ConcertNotFoundException"));
    }

    @Test
    @DisplayName("최근 찜한 순이고 남의 찜은 섞이지 않는다")
    void newestFirstAndMineOnly() throws Exception {
        mvc.perform(put(WISHES_PATH + "/{concertId}", first.getId())).andExpect(status().isNoContent());
        mvc.perform(put(WISHES_PATH + "/{concertId}", second.getId())).andExpect(status().isNoContent());
        concertWishRepository.saveAndFlush(ConcertWish.builder().member(other).concert(first).build());

        mvc.perform(get(WISHES_PATH + "/me"))
                .andExpect(jsonPath("$.page.totalElements").value(2))
                .andExpect(jsonPath("$.content[*].id").value(contains(
                        second.getId().intValue(), first.getId().intValue())));
    }

    @Test
    @DisplayName("size 상한은 100")
    void sizeLimit() throws Exception {
        mvc.perform(get(WISHES_PATH + "/me").param("size", "101"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("같은 회원과 공연의 찜은 스키마가 막는다 - 서비스가 삼키는 위반의 실체")
    void uniqueConstraintIsReal() {
        concertWishRepository.saveAndFlush(ConcertWish.builder().member(me).concert(first).build());

        assertThatThrownBy(() -> concertWishRepository.saveAndFlush(
                ConcertWish.builder().member(me).concert(first).build()))
                .isInstanceOf(DataIntegrityViolationException.class);
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
