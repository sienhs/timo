package com.ssafy.timo.domain.concert.service;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.exception.ArtistNotFoundException;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertDetailResponseDto;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.BookingBlockReason;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertImage;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.exception.InvalidConcertPeriodException;
import com.ssafy.timo.domain.concert.exception.InvalidTicketOpenTimeException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.concert.view.ViewCountStore;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.assertj.core.groups.Tuple;
import org.springframework.test.util.ReflectionTestUtils;

import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.Mockito.never;

@ExtendWith(MockitoExtension.class)
class ConcertServiceImplTest {

    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

    private static final LocalDateTime OPEN_AT = LocalDateTime.of(2026, 3, 1, 20, 0);
    private static final LocalDateTime START = LocalDateTime.of(2026, 4, 10, 19, 0);
    private static final LocalDateTime END = LocalDateTime.of(2026, 4, 12, 21, 0);

    /** 오픈은 지났고 마감({@code START - 2h})은 아직인 시각. 예매 창 안이다. */
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 3, 15, 12, 0);

    private static final String POSTER_KEY = "concert/1/poster.png";
    private static final List<String> IMAGE_KEYS =
            List.of("concert/1/detail-1.png", "concert/1/detail-2.png");

    @Mock
    private ConcertRepository concertRepository;

    @Mock
    private ViewCountStore viewCountStore;

    @Mock
    private VenueRepository venueRepository;

    @Mock
    private ArtistRepository artistRepository;

    @Mock
    private SectionRepository sectionRepository;

    @Mock
    private ImageStorage imageStorage;

    private ConcertServiceImpl concertService;

    /**
     * {@code @InjectMocks} 를 쓰지 않는다. {@link Clock} 까지 목으로 꽂히면 {@code instant()} 가
     * null 을 돌려줘 상세 조회가 그 자리에서 터진다. 시계는 가짜가 아니라 <b>고정된 진짜</b>가
     * 필요하므로 직접 조립한다.
     */
    @BeforeEach
    void setUpService() {
        concertService = new ConcertServiceImpl(
                concertRepository,
                viewCountStore,
                venueRepository,
                artistRepository,
                sectionRepository,
                imageStorage,
                Clock.fixed(NOW.atZone(ZONE).toInstant(), ZONE));
    }

    @Captor
    private ArgumentCaptor<Concert> concertCaptor;

    @Test
    @DisplayName("공연을 생성하면 공연장·아티스트 정보까지 담긴 응답이 반환된다")
    void create_success() {
        // given
        givenVenueExists();
        givenArtistsExist();
        givenConcertSaved();
        givenImageStoragePrefixesKeys();

        // when
        CommandConcertResponseDto response = concertService.create(request(List.of(20L, 21L)));

        // then
        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.title()).isEqualTo("아이유 콘서트");
        assertThat(response.genre()).isEqualTo(ConcertGenre.CONCERT);
        assertThat(response.ageRating()).isEqualTo(AgeRating.AGE_7);
        assertThat(response.venueId()).isEqualTo(10L);
        assertThat(response.venueName()).isEqualTo("고척돔");
    }

    @Test
    @DisplayName("출연 아티스트가 요청한 순서 그대로 응답에 담긴다")
    void create_keepsRequestedArtistOrder() {
        // given
        givenVenueExists();
        givenArtistsExist();
        givenConcertSaved();

        // when
        CommandConcertResponseDto response = concertService.create(request(List.of(21L, 20L)));

        // then
        assertThat(response.artists())
                .extracting(CommandConcertResponseDto.ArtistSummary::id)
                .containsExactly(21L, 20L);
        assertThat(response.artists())
                .extracting(CommandConcertResponseDto.ArtistSummary::name)
                .containsExactly("박효신", "아이유");
    }

    @Test
    @DisplayName("이미지 key 는 저장소를 거쳐 URL 로 변환돼 응답에 담긴다")
    void create_resolvesImageKeysToUrls() {
        // given
        givenVenueExists();
        givenArtistsExist();
        givenConcertSaved();
        givenImageStoragePrefixesKeys();

        // when
        CommandConcertResponseDto response = concertService.create(request(List.of(20L)));

        // then
        assertThat(response.posterImageUrl()).isEqualTo("https://cdn.timo.io/" + POSTER_KEY);
        assertThat(response.imageUrls()).containsExactly(
                "https://cdn.timo.io/concert/1/detail-1.png",
                "https://cdn.timo.io/concert/1/detail-2.png");
    }

    @Test
    @DisplayName("상세 이미지는 요청 순서대로 노출 순서가 매겨진다")
    void create_assignsSortOrderByRequestOrder() {
        // given
        givenVenueExists();
        givenArtistsExist();
        givenConcertSaved();

        // when
        concertService.create(request(List.of(20L)));

        // then
        then(concertRepository).should().save(concertCaptor.capture());

        assertThat(concertCaptor.getValue().getImages())
                .extracting(ConcertImage::getImageKey, ConcertImage::getSortOrder)
                .containsExactly(
                        Tuple.tuple("concert/1/detail-1.png", 0),
                        Tuple.tuple("concert/1/detail-2.png", 1));
    }

    @Test
    @DisplayName("생성된 공연은 항상 예매 전 상태이고 조회수는 0이다")
    void create_startsAsScheduledWithZeroViewCount() {
        // given
        givenVenueExists();
        givenArtistsExist();
        givenConcertSaved();

        // when
        CommandConcertResponseDto response = concertService.create(request(List.of(20L)));

        // then
        assertThat(response.status()).isEqualTo(ConcertStatus.SCHEDULED);
        assertThat(response.viewCount()).isZero();
    }

    @Test
    @DisplayName("같은 아티스트가 중복으로 들어오면 한 번만 등록된다")
    void create_deduplicatesArtistIds() {
        // given
        givenVenueExists();
        given(artistRepository.findAllById(anyList())).willReturn(List.of(artist(20L, "아이유")));
        givenConcertSaved();

        // when
        CommandConcertResponseDto response = concertService.create(request(List.of(20L, 20L, 20L)));

        // then
        assertThat(response.artists()).hasSize(1);
        assertThat(response.artists().get(0).id()).isEqualTo(20L);
    }

    @Test
    @DisplayName("이미지를 넣지 않아도 공연은 생성된다")
    void create_allowsNoImages() {
        // given
        givenVenueExists();
        givenArtistsExist();
        givenConcertSaved();

        // when
        CommandConcertResponseDto response = concertService.create(
                new CommandConcertRequestDto("아이유 콘서트", ConcertGenre.CONCERT, null, null,
                        "설명", AgeRating.AGE_7, START, END, OPEN_AT, 10L, List.of(20L)));

        // then
        assertThat(response.imageUrls()).isEmpty();
        assertThat(response.posterImageUrl()).isNull();
    }

    @Test
    @DisplayName("일정을 넣지 않아도 공연은 생성된다")
    void create_allowsNullSchedule() {
        // given
        givenVenueExists();
        givenArtistsExist();
        givenConcertSaved();

        // when
        CommandConcertResponseDto response = concertService.create(
                request(List.of(20L), null, null, null));

        // then
        assertThat(response.startDate()).isNull();
        assertThat(response.endDate()).isNull();
        assertThat(response.openAt()).isNull();
    }

    @Test
    @DisplayName("존재하지 않는 공연장이면 저장하지 않고 예외를 던진다")
    void create_throwsWhenVenueNotFound() {
        // given
        given(venueRepository.findById(10L)).willReturn(Optional.empty());

        // when & then
        assertThatThrownBy(() -> concertService.create(request(List.of(20L))))
                .isInstanceOf(VenueNotFoundException.class)
                .hasMessageContaining("10");

        then(concertRepository).should(never()).save(any(Concert.class));
    }

    @Test
    @DisplayName("아티스트 중 하나라도 없으면 저장하지 않고 그 ID로 예외를 던진다")
    void create_throwsWhenAnyArtistNotFound() {
        // given
        givenVenueExists();
        given(artistRepository.findAllById(anyList())).willReturn(List.of(artist(20L, "아이유")));

        // when & then
        assertThatThrownBy(() -> concertService.create(request(List.of(20L, 99L))))
                .isInstanceOf(ArtistNotFoundException.class)
                .hasMessageContaining("99");

        then(concertRepository).should(never()).save(any(Concert.class));
    }

    @Test
    @DisplayName("종료일이 시작일보다 빠르면 조회조차 하지 않고 예외를 던진다")
    void create_rejectsEndDateBeforeStartDate() {
        // when & then
        assertThatThrownBy(() -> concertService.create(
                request(List.of(20L), START, START.minusDays(1), OPEN_AT)))
                .isInstanceOf(InvalidConcertPeriodException.class);

        then(venueRepository).shouldHaveNoInteractions();
        then(artistRepository).shouldHaveNoInteractions();
        then(concertRepository).shouldHaveNoInteractions();
    }

    @Test
    @DisplayName("예매 오픈이 공연 시작 이후면 예외를 던진다")
    void create_rejectsOpenAtAfterStartDate() {
        // when & then
        assertThatThrownBy(() -> concertService.create(
                request(List.of(20L), START, END, START.plusHours(1))))
                .isInstanceOf(InvalidTicketOpenTimeException.class);

        then(concertRepository).shouldHaveNoInteractions();
    }

    @Test
    @DisplayName("공연을 조회하면 공연장·아티스트·이미지까지 담긴 응답이 반환된다")
    void find_success() {
        // given
        Concert concert = concertWithId(1L);
        given(concertRepository.findByIdWithVenue(1L)).willReturn(Optional.of(concert));
        given(viewCountStore.incrementAndGet(1L, 0)).willReturn(1);
        givenImageStoragePrefixesKeys();

        // when
        ConcertDetailResponseDto response = concertService.find(1L);

        // then
        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.title()).isEqualTo("아이유 콘서트");
        assertThat(response.venueId()).isEqualTo(10L);
        assertThat(response.venueName()).isEqualTo("고척돔");
        assertThat(response.artists())
                .extracting(ConcertDetailResponseDto.ArtistSummary::name)
                .containsExactly("아이유", "박효신");
        assertThat(response.imageUrls()).containsExactly(
                "https://cdn.timo.io/concert/1/detail-1.png",
                "https://cdn.timo.io/concert/1/detail-2.png");
    }

    @Test
    @DisplayName("상세 응답에 공연장의 구역별 가격이 담긴다")
    void find_includesSectionPrices() {
        // given
        Concert concert = concertWithId(1L);
        given(concertRepository.findByIdWithVenue(1L)).willReturn(Optional.of(concert));
        given(viewCountStore.incrementAndGet(1L, 0)).willReturn(1);
        givenImageStoragePrefixesKeys();
        given(sectionRepository.findAllByVenueIdOrderByIdAsc(10L))
                .willReturn(List.of(section(1L, "A구역", 150_000), section(2L, "B구역", 99_000)));

        // when
        ConcertDetailResponseDto response = concertService.find(1L);

        // then
        assertThat(response.sectionPrices())
                .extracting(ConcertDetailResponseDto.SectionPrice::sectionName,
                        ConcertDetailResponseDto.SectionPrice::price)
                .containsExactly(Tuple.tuple("A구역", 150_000), Tuple.tuple("B구역", 99_000));
    }

    @Test
    @DisplayName("좌석을 아직 등록하지 않은 공연장이면 구역별 가격은 빈 목록이다")
    void find_returnsEmptySectionPricesWhenVenueHasNoSection() {
        // given
        given(concertRepository.findByIdWithVenue(1L)).willReturn(Optional.of(concertWithId(1L)));
        given(viewCountStore.incrementAndGet(1L, 0)).willReturn(1);
        givenImageStoragePrefixesKeys();
        given(sectionRepository.findAllByVenueIdOrderByIdAsc(10L)).willReturn(List.of());

        // when
        ConcertDetailResponseDto response = concertService.find(1L);

        // then — 오류가 아니다. 공연장만 만들고 배치도를 아직 안 넣은 상태다.
        assertThat(response.sectionPrices()).isEmpty();
    }

    /** 가격만 보는 테스트라 격자·좌석 수는 채우지 않는다. */
    private static Section section(Long id, String name, int price) {
        Section section = Section.builder()
                .name(name)
                .price(price)
                .build();
        ReflectionTestUtils.setField(section, "id", id);
        return section;
    }

    @Test
    @DisplayName("조회할 때마다 메모리 조회수 저장소를 통해 1 증가한다")
    void find_increasesViewCountInStore() {
        // given
        given(concertRepository.findByIdWithVenue(1L)).willReturn(Optional.of(concertWithId(1L)));
        given(viewCountStore.incrementAndGet(1L, 0)).willReturn(1);

        // when
        concertService.find(1L);

        // then
        then(viewCountStore).should().incrementAndGet(1L, 0);
    }

    @Test
    @DisplayName("존재하지 않는 공연이면 조회하지 않고 예외를 던진다")
    void find_throwsWhenNotFound() {
        // given
        given(concertRepository.findByIdWithVenue(99L)).willReturn(Optional.empty());

        // when & then
        assertThatThrownBy(() -> concertService.find(99L))
                .isInstanceOf(ConcertNotFoundException.class)
                .hasMessageContaining("99");

        then(viewCountStore).shouldHaveNoInteractions();
    }

    private void givenVenueExists() {
        given(venueRepository.findById(10L)).willReturn(Optional.of(venue()));
    }

    private void givenArtistsExist() {
        given(artistRepository.findAllById(anyList()))
                .willReturn(List.of(artist(20L, "아이유"), artist(21L, "박효신")));
    }

    private void givenConcertSaved() {
        given(concertRepository.save(any(Concert.class))).willAnswer(inv -> withId(inv.getArgument(0), 1L));
    }

    private void givenImageStoragePrefixesKeys() {
        given(imageStorage.getUrl(any())).willAnswer(inv -> {
            String key = inv.getArgument(0);
            return key == null ? null : "https://cdn.timo.io/" + key;
        });
    }

    private CommandConcertRequestDto request(List<Long> artistIds) {
        return request(artistIds, START, END, OPEN_AT);
    }

    private CommandConcertRequestDto request(List<Long> artistIds,
                                             LocalDateTime startDate,
                                             LocalDateTime endDate,
                                             LocalDateTime openAt) {
        return new CommandConcertRequestDto(
                "아이유 콘서트",
                ConcertGenre.CONCERT,
                POSTER_KEY,
                IMAGE_KEYS,
                "2026 아이유 단독 콘서트",
                AgeRating.AGE_7,
                startDate,
                endDate,
                openAt,
                10L,
                artistIds);
    }

    private Venue venue() {
        Venue venue = Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build();
        ReflectionTestUtils.setField(venue, "id", 10L);
        return venue;
    }

    private Artist artist(Long id, String name) {
        Artist artist = Artist.builder()
                .name(name)
                .profileImageKey("artist/" + id + "/profile.png")
                .build();
        ReflectionTestUtils.setField(artist, "id", id);
        return artist;
    }

    /** save() 이후 상태를 재현하기 위해 식별자만 리플렉션으로 채운다. */
    private Concert withId(Concert concert, Long id) {
        ReflectionTestUtils.setField(concert, "id", id);
        return concert;
    }

    /** 상세 조회 응답을 검증하기 위해 공연장·아티스트·이미지가 모두 채워진 공연을 만든다. */
    @Test
    @DisplayName("예매 중이 아닌 공연은 예매 불가로, 사유까지 함께 답한다")
    void find_notOnSale_isNotBookable() {
        // 등록 직후의 공연은 SCHEDULED 다. 오픈 시각이 지났는지와 무관하게 예매가 성립하지 않는다.
        Concert concert = concertWithId(1L);
        given(concertRepository.findByIdWithVenue(1L)).willReturn(Optional.of(concert));
        given(viewCountStore.incrementAndGet(1L, 0)).willReturn(1);
        givenImageStoragePrefixesKeys();

        ConcertDetailResponseDto response = concertService.find(1L);

        assertThat(response.bookable()).isFalse();
        assertThat(response.blockReason()).isEqualTo(BookingBlockReason.NOT_ON_SALE);
    }

    @Test
    @DisplayName("예매 창 안이면 예매 가능으로 답하고 사유는 비운다")
    void find_withinBookingWindow_isBookable() {
        Concert concert = concertWithId(1L);
        ReflectionTestUtils.setField(concert, "status", ConcertStatus.ON_SALE);
        given(concertRepository.findByIdWithVenue(1L)).willReturn(Optional.of(concert));
        given(viewCountStore.incrementAndGet(1L, 0)).willReturn(1);
        givenImageStoragePrefixesKeys();

        ConcertDetailResponseDto response = concertService.find(1L);

        assertThat(response.bookable()).isTrue();
        assertThat(response.blockReason()).isNull();
    }

    @Test
    @DisplayName("예매 중이라도 마감을 지났으면 예매 불가로 답한다 - status 는 그대로 ON_SALE 이다")
    void find_pastCutoff_isNotBookableEvenWhileOnSale() {
        // 상태 컬럼은 1분마다 미는 거친 라벨이라 마감~종료 구간에서는 ON_SALE 로 남는다.
        // 그 어긋남을 클라이언트가 겪지 않게 하는 것이 bookable 의 존재 이유다.
        Concert concert = concertWithId(1L);
        ReflectionTestUtils.setField(concert, "status", ConcertStatus.ON_SALE);
        ReflectionTestUtils.setField(concert, "startDate", NOW.plusHours(1));
        given(concertRepository.findByIdWithVenue(1L)).willReturn(Optional.of(concert));
        given(viewCountStore.incrementAndGet(1L, 0)).willReturn(1);
        givenImageStoragePrefixesKeys();

        ConcertDetailResponseDto response = concertService.find(1L);

        assertThat(response.status()).isEqualTo(ConcertStatus.ON_SALE);
        assertThat(response.bookable()).isFalse();
        assertThat(response.blockReason()).isEqualTo(BookingBlockReason.CLOSED);
    }

    private Concert concertWithId(Long id) {
        Concert concert = Concert.builder()
                .title("아이유 콘서트")
                .genre(ConcertGenre.CONCERT)
                .posterImageKey(POSTER_KEY)
                .description("2026 아이유 단독 콘서트")
                .ageRating(AgeRating.AGE_7)
                .startDate(START)
                .endDate(END)
                .openAt(OPEN_AT)
                .venue(venue())
                .build();
        concert.addArtist(artist(20L, "아이유"));
        concert.addArtist(artist(21L, "박효신"));
        IMAGE_KEYS.forEach(concert::addImage);
        return withId(concert, id);
    }
}
