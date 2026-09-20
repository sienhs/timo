package com.ssafy.timo.domain.wish;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.domain.wish.dto.WishedConcertRow;
import com.ssafy.timo.domain.wish.entity.ConcertWish;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.support.IntegrationTest;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

/** 여러 공연의 찜을 한 번에 읽는 쿼리를 실제 MySQL 로 확인한다. 양도 매물 알림의 대상이 여기서 나온다. */
@IntegrationTest
class ConcertWishRepositoryTest {

    @Autowired
    private ConcertWishRepository wishRepository;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private MemberRepository memberRepository;

    private Venue venue;

    @BeforeEach
    void setUp() {
        venue = venueRepository.save(Venue.builder()
                .name("공연장-" + UUID.randomUUID().toString().substring(0, 6))
                .address("서울시 송파구")
                .totalSeatCount(5000)
                .build());
    }

    @Test
    @DisplayName("요청한 공연들의 찜만 회원 id 와 공연 id 쌍으로 돌려준다")
    void findAllByConcertIdIn_returnsPairsOfRequestedConcertsOnly() {
        Concert first = concert("첫 공연");
        Concert second = concert("둘째 공연");
        Concert notAsked = concert("묻지 않은 공연");
        Member a = member("a");
        Member b = member("b");
        wish(a, first);
        wish(a, second);
        wish(b, second);
        wish(b, notAsked);

        List<WishedConcertRow> rows = wishRepository.findAllByConcertIdIn(List.of(first.getId(), second.getId()));

        assertThat(rows)
                .extracting(WishedConcertRow::getMemberId, WishedConcertRow::getConcertId)
                .containsExactlyInAnyOrder(
                        org.assertj.core.groups.Tuple.tuple(a.getId(), first.getId()),
                        org.assertj.core.groups.Tuple.tuple(a.getId(), second.getId()),
                        org.assertj.core.groups.Tuple.tuple(b.getId(), second.getId()));
    }

    @Test
    @DisplayName("찜한 사람이 없으면 빈 목록이다")
    void findAllByConcertIdIn_noWishes_isEmpty() {
        Concert concert = concert("공연");

        assertThat(wishRepository.findAllByConcertIdIn(List.of(concert.getId()))).isEmpty();
    }

    @Test
    @DisplayName("공연 목록이 비어 있어도 예외 없이 빈 목록이다")
    void findAllByConcertIdIn_emptyCollection_isEmpty() {
        assertThat(wishRepository.findAllByConcertIdIn(List.of())).isEmpty();
    }

    private void wish(Member member, Concert concert) {
        wishRepository.save(ConcertWish.builder().member(member).concert(concert).build());
    }

    private Concert concert(String title) {
        return concertRepository.save(Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .startDate(LocalDateTime.of(2026, 12, 1, 19, 0))
                .endDate(LocalDateTime.of(2026, 12, 1, 22, 0))
                .openAt(LocalDateTime.of(2026, 10, 1, 20, 0))
                .venue(venue)
                .build());
    }

    private Member member(String nickname) {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        return memberRepository.save(Member.builder()
                .phoneNumber("010" + suffix.replaceAll("[a-z]", "1"))
                .name("정희성")
                .nickname(nickname + suffix)
                .build());
    }
}
