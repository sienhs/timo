package com.ssafy.timo.domain.alarm;

import static com.ssafy.timo.domain.alarm.entity.AlarmType.CONCERT_OPEN;
import static com.ssafy.timo.domain.alarm.entity.AlarmType.MARKET_LISTING;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ssafy.timo.domain.alarm.dto.AlarmedConcertRow;
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
import com.ssafy.timo.support.IntegrationTest;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import org.assertj.core.groups.Tuple;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

/**
 * 공연 알림 신청 리포지토리의 쿼리와 제약을 실제 MySQL 로 확인한다. 예매 오픈·양도 매물 알림의 대상이 여기서
 * 나오며, 두 종류는 서로 섞이지 않아야 한다.
 */
@IntegrationTest
class ConcertAlarmRepositoryTest {

    @Autowired
    private ConcertAlarmRepository alarmRepository;

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
    @DisplayName("같은 회원이 같은 공연의 같은 종류를 두 번 신청하면 유니크 제약이 막는다")
    void save_duplicateTriple_violatesUniqueConstraint() {
        Concert concert = concert("공연");
        Member member = member("a");
        alarmRepository.saveAndFlush(alarm(member, concert, CONCERT_OPEN));

        assertThatThrownBy(() -> alarmRepository.saveAndFlush(alarm(member, concert, CONCERT_OPEN)))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    @DisplayName("같은 회원이 같은 공연의 다른 종류는 각각 신청할 수 있다")
    void save_sameConcertDifferentType_isAllowed() {
        Concert concert = concert("공연");
        Member member = member("a");
        alarmRepository.saveAndFlush(alarm(member, concert, CONCERT_OPEN));
        alarmRepository.saveAndFlush(alarm(member, concert, MARKET_LISTING));

        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(member.getId(), concert.getId(), CONCERT_OPEN))
                .isTrue();
        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(member.getId(), concert.getId(), MARKET_LISTING))
                .isTrue();
    }

    @Test
    @DisplayName("신청 여부는 회원, 공연, 종류 한 조합으로 확인한다")
    void existsByMemberIdAndConcertIdAndType_matchesTripleOnly() {
        Concert first = concert("첫 공연");
        Concert second = concert("둘째 공연");
        Member me = member("me");
        Member other = member("other");
        alarmRepository.save(alarm(me, first, CONCERT_OPEN));

        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(me.getId(), first.getId(), CONCERT_OPEN))
                .isTrue();
        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(me.getId(), first.getId(), MARKET_LISTING))
                .isFalse();
        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(me.getId(), second.getId(), CONCERT_OPEN))
                .isFalse();
        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(other.getId(), first.getId(), CONCERT_OPEN))
                .isFalse();
    }

    @Test
    @DisplayName("내가 한 공연에 신청한 종류만 돌려준다 - 다른 공연과 다른 회원의 신청은 섞이지 않는다")
    void findTypesByMemberIdAndConcertId_returnsOwnTypesOfThatConcertOnly() {
        Concert first = concert("첫 공연");
        Concert second = concert("둘째 공연");
        Member me = member("me");
        Member other = member("other");
        alarmRepository.save(alarm(me, first, CONCERT_OPEN));
        alarmRepository.save(alarm(me, first, MARKET_LISTING));
        alarmRepository.save(alarm(me, second, CONCERT_OPEN));
        alarmRepository.save(alarm(other, first, CONCERT_OPEN));

        assertThat(alarmRepository.findTypesByMemberIdAndConcertId(me.getId(), first.getId()))
                .containsExactlyInAnyOrder(CONCERT_OPEN, MARKET_LISTING);
        assertThat(alarmRepository.findTypesByMemberIdAndConcertId(me.getId(), second.getId()))
                .containsExactly(CONCERT_OPEN);
    }

    @Test
    @DisplayName("신청한 것이 없으면 종류 목록은 비어 있다")
    void findTypesByMemberIdAndConcertId_noAlarms_isEmpty() {
        Concert concert = concert("공연");
        Member member = member("a");

        assertThat(alarmRepository.findTypesByMemberIdAndConcertId(member.getId(), concert.getId())).isEmpty();
    }

    @Test
    @DisplayName("해제는 그 조합만 지우고 영향 행 수를 돌려준다. 같은 공연의 다른 종류는 남는다")
    void deleteByMemberIdAndConcertIdAndType_removesOnlyThatTriple() {
        Concert first = concert("첫 공연");
        Concert second = concert("둘째 공연");
        Member me = member("me");
        Member other = member("other");
        alarmRepository.save(alarm(me, first, CONCERT_OPEN));
        alarmRepository.save(alarm(me, first, MARKET_LISTING));
        alarmRepository.save(alarm(me, second, CONCERT_OPEN));
        alarmRepository.save(alarm(other, first, CONCERT_OPEN));

        int deleted = alarmRepository.deleteByMemberIdAndConcertIdAndType(me.getId(), first.getId(), CONCERT_OPEN);

        assertThat(deleted).isEqualTo(1);
        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(me.getId(), first.getId(), CONCERT_OPEN))
                .isFalse();
        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(me.getId(), first.getId(), MARKET_LISTING))
                .isTrue();
        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(me.getId(), second.getId(), CONCERT_OPEN))
                .isTrue();
        assertThat(alarmRepository.existsByMemberIdAndConcertIdAndType(other.getId(), first.getId(), CONCERT_OPEN))
                .isTrue();
    }

    @Test
    @DisplayName("신청하지 않은 공연을 해제해도 예외 없이 0 을 돌려준다")
    void deleteByMemberIdAndConcertIdAndType_noAlarm_returnsZero() {
        Concert concert = concert("공연");
        Member member = member("a");

        assertThat(alarmRepository.deleteByMemberIdAndConcertIdAndType(member.getId(), concert.getId(), CONCERT_OPEN))
                .isZero();
    }

    @Test
    @DisplayName("내 신청 목록은 내 것만, 그 종류만, 최근 신청한 순으로 돌려준다")
    void findPageOfMember_ownOnly_sameTypeOnly_latestFirst() {
        Concert first = concert("첫 공연");
        Concert second = concert("둘째 공연");
        Concert third = concert("셋째 공연");
        Member me = member("me");
        Member other = member("other");
        alarmRepository.save(alarm(me, first, CONCERT_OPEN));
        alarmRepository.save(alarm(me, second, CONCERT_OPEN));
        alarmRepository.save(alarm(me, second, MARKET_LISTING));
        alarmRepository.save(alarm(other, third, CONCERT_OPEN));
        alarmRepository.save(alarm(me, third, CONCERT_OPEN));

        Page<ConcertAlarm> page = alarmRepository.findPageOfMember(
                me.getId(), CONCERT_OPEN, PageRequest.of(0, 10, Sort.unsorted()));

        assertThat(page.getTotalElements()).isEqualTo(3);
        assertThat(page.getContent())
                .extracting(alarm -> alarm.getConcert().getId())
                .containsExactly(third.getId(), second.getId(), first.getId());
    }

    @Test
    @DisplayName("내 신청 목록은 페이지 크기만큼 자르고 전체 건수를 함께 돌려준다")
    void findPageOfMember_paging() {
        Member me = member("me");
        Concert first = concert("첫 공연");
        Concert second = concert("둘째 공연");
        Concert third = concert("셋째 공연");
        alarmRepository.save(alarm(me, first, MARKET_LISTING));
        alarmRepository.save(alarm(me, second, MARKET_LISTING));
        alarmRepository.save(alarm(me, third, MARKET_LISTING));

        Page<ConcertAlarm> secondPage = alarmRepository.findPageOfMember(
                me.getId(), MARKET_LISTING, PageRequest.of(1, 2, Sort.unsorted()));

        assertThat(secondPage.getTotalElements()).isEqualTo(3);
        assertThat(secondPage.getContent())
                .extracting(alarm -> alarm.getConcert().getId())
                .containsExactly(first.getId());
    }

    @Test
    @DisplayName("한 공연의 그 종류 알림 신청 회원 id 만 돌려준다")
    void findMemberIdsByConcertIdAndType_returnsSubscribersOfThatConcertAndType() {
        Concert concert = concert("공연");
        Concert another = concert("다른 공연");
        Member a = member("a");
        Member b = member("b");
        Member c = member("c");
        Member d = member("d");
        alarmRepository.save(alarm(a, concert, CONCERT_OPEN));
        alarmRepository.save(alarm(b, concert, CONCERT_OPEN));
        alarmRepository.save(alarm(c, another, CONCERT_OPEN));
        alarmRepository.save(alarm(d, concert, MARKET_LISTING));

        assertThat(alarmRepository.findMemberIdsByConcertIdAndType(concert.getId(), CONCERT_OPEN))
                .containsExactlyInAnyOrder(a.getId(), b.getId());
    }

    @Test
    @DisplayName("신청한 사람이 없는 공연은 빈 목록이다")
    void findMemberIdsByConcertIdAndType_noAlarms_isEmpty() {
        Concert concert = concert("공연");

        assertThat(alarmRepository.findMemberIdsByConcertIdAndType(concert.getId(), CONCERT_OPEN)).isEmpty();
    }

    @Test
    @DisplayName("요청한 공연들의 그 종류 신청만 회원 id 와 공연 id 쌍으로 돌려준다")
    void findAllByConcertIdInAndType_returnsPairsOfRequestedConcertsAndTypeOnly() {
        Concert first = concert("첫 공연");
        Concert second = concert("둘째 공연");
        Concert notAsked = concert("묻지 않은 공연");
        Member a = member("a");
        Member b = member("b");
        alarmRepository.save(alarm(a, first, MARKET_LISTING));
        alarmRepository.save(alarm(a, second, MARKET_LISTING));
        alarmRepository.save(alarm(b, second, MARKET_LISTING));
        alarmRepository.save(alarm(b, notAsked, MARKET_LISTING));
        alarmRepository.save(alarm(b, first, CONCERT_OPEN));

        List<AlarmedConcertRow> rows = alarmRepository.findAllByConcertIdInAndType(
                List.of(first.getId(), second.getId()), MARKET_LISTING);

        assertThat(rows)
                .extracting(AlarmedConcertRow::getMemberId, AlarmedConcertRow::getConcertId)
                .containsExactlyInAnyOrder(
                        Tuple.tuple(a.getId(), first.getId()),
                        Tuple.tuple(a.getId(), second.getId()),
                        Tuple.tuple(b.getId(), second.getId()));
    }

    @Test
    @DisplayName("신청한 사람이 없으면 빈 목록이다")
    void findAllByConcertIdInAndType_noAlarms_isEmpty() {
        Concert concert = concert("공연");

        assertThat(alarmRepository.findAllByConcertIdInAndType(List.of(concert.getId()), MARKET_LISTING)).isEmpty();
    }

    @Test
    @DisplayName("공연 목록이 비어 있어도 예외 없이 빈 목록이다")
    void findAllByConcertIdInAndType_emptyCollection_isEmpty() {
        assertThat(alarmRepository.findAllByConcertIdInAndType(List.of(), MARKET_LISTING)).isEmpty();
    }

    private ConcertAlarm alarm(Member member, Concert concert, AlarmType type) {
        return ConcertAlarm.builder().member(member).concert(concert).type(type).build();
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
