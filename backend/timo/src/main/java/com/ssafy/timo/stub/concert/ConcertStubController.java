package com.ssafy.timo.stub.concert;

import com.ssafy.timo.domain.artist.exception.ArtistNotFoundException;
import com.ssafy.timo.domain.concert.controller.ConcertApi;
import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertDetailResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertListRequestDto;
import com.ssafy.timo.domain.concert.dto.ConcertSortType;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.exception.InvalidConcertPeriodException;
import com.ssafy.timo.domain.concert.exception.InvalidTicketOpenTimeException;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.global.storage.ImageStorage;
import com.ssafy.timo.stub.StubController;
import com.ssafy.timo.stub.StubFixtures;
import com.ssafy.timo.stub.StubFixtures.ArtistFixture;
import com.ssafy.timo.stub.StubFixtures.ConcertFixture;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;

import java.net.URI;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/**
 * 공연 API 스텁 (v0).
 *
 * <p>고정 공연 4건({@link StubFixtures#CONCERTS}) 위에 이 프로세스에서 생성한 공연을 덧붙여 돌려준다.
 * 상태는 {@link ConcertStore} 가 들고 있어 관리자 스텁이 공연을 종료시키면 여기서도 {@code CLOSED} 로 보인다.
 *
 * <p>목록의 필터·정렬·페이지는 실제와 같은 규칙으로 메모리에서 계산한다. 정렬은
 * {@link ConcertSortType} 의 기준을 그대로 옮긴 것이고, 동점은 실제처럼 id 내림차순이다.
 *
 * <p>이미지 key → URL 변환은 실제와 같은 {@link ImageStorage} 를 쓴다. 스텁이 URL 모양을 따로 정하면
 * v1 으로 옮길 때 화면의 이미지 경로가 달라진다.
 */
@StubController
@RequestMapping(ConcertStubController.BASE_PATH)
public class ConcertStubController implements ConcertApi {

    static final String BASE_PATH = "/api/v0/concerts";

    private final ConcertStore concertStore;
    private final ImageStorage imageStorage;

    public ConcertStubController(ConcertStore concertStore, ImageStorage imageStorage) {
        this.concertStore = concertStore;
        this.imageStorage = imageStorage;
    }

    @Override
    public ResponseEntity<CommandConcertResponseDto> create(CommandConcertRequestDto request) {
        if (request.venueId() == StubFixtures.NOT_FOUND_ID) {
            throw new VenueNotFoundException(request.venueId());
        }
        List<Long> artistIds = request.artistIds().stream().distinct().toList();
        artistIds.stream()
                .filter(id -> id == StubFixtures.NOT_FOUND_ID)
                .findFirst()
                .ifPresent(id -> {
                    throw new ArtistNotFoundException(id);
                });
        validatePeriod(request.startDate(), request.endDate(), request.openAt());

        ConcertFixture concert = new ConcertFixture(
                concertStore.nextId(),
                request.title(),
                request.genre(),
                request.posterImageKey(),
                request.imageKeysOrEmpty(),
                request.description(),
                request.ageRating(),
                ConcertStatus.SCHEDULED,
                0,
                request.startDate(),
                request.endDate(),
                request.openAt(),
                request.venueId(),
                StubFixtures.VENUE_NAME,
                artistIds);
        concertStore.save(concert);

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/" + concert.id()))
                .body(toCommandResponse(concert));
    }

    @Override
    public ResponseEntity<PagedModel<ConcertSummaryResponseDto>> findAll(ConcertListRequestDto request) {
        String keyword = request.keywordOrNull();
        List<ConcertFixture> matched = new ArrayList<>(concertStore.all()
                .filter(concert -> request.genre() == null || concert.genre() == request.genre())
                .filter(concert -> request.status() == null || concert.status() == request.status())
                .filter(concert -> keyword == null
                        || concert.title().toLowerCase().contains(keyword.toLowerCase()))
                .toList());
        matched.sort(comparator(request.sort()));

        Pageable pageable = request.toPageable();
        int from = (int) Math.min(pageable.getOffset(), matched.size());
        int to = Math.min(from + pageable.getPageSize(), matched.size());
        List<ConcertSummaryResponseDto> content = matched.subList(from, to).stream()
                .map(this::toSummary)
                .toList();

        return ResponseEntity.ok(new PagedModel<>(new PageImpl<>(content, pageable, matched.size())));
    }

    @Override
    public ResponseEntity<ConcertDetailResponseDto> find(Long concertId) {
        ConcertFixture concert = concertStore.find(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));

        return ResponseEntity.ok(toDetail(concert));
    }

    /** 실제 {@code ConcertServiceImpl} 의 기간 검증을 옮겨 왔다. 프론트가 400 분기를 볼 수 있어야 한다. */
    private static void validatePeriod(LocalDateTime startDate, LocalDateTime endDate, LocalDateTime openAt) {
        if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
            throw new InvalidConcertPeriodException();
        }
        if (startDate != null && openAt != null && !openAt.isBefore(startDate)) {
            throw new InvalidTicketOpenTimeException();
        }
    }

    /** {@link ConcertSortType} 과 같은 기준. null 은 뒤로, 동점은 id 내림차순. */
    private static Comparator<ConcertFixture> comparator(ConcertSortType sort) {
        Comparator<ConcertFixture> byIdDesc = Comparator.comparingLong(ConcertFixture::id).reversed();
        ConcertSortType effective = sort == null ? ConcertSortType.LATEST : sort;

        Comparator<ConcertFixture> primary = switch (effective) {
            // createdAt 이 없어 id 순서를 등록 순서로 본다.
            case LATEST -> byIdDesc;
            case POPULAR -> Comparator.comparingInt(ConcertFixture::viewCount).reversed();
            case OPEN_SOON -> Comparator.comparing(ConcertFixture::openAt,
                    Comparator.nullsLast(Comparator.naturalOrder()));
            case START_DATE -> Comparator.comparing(ConcertFixture::startDate,
                    Comparator.nullsLast(Comparator.naturalOrder()));
        };
        return primary.thenComparing(byIdDesc);
    }

    private ConcertSummaryResponseDto toSummary(ConcertFixture concert) {
        return new ConcertSummaryResponseDto(
                concert.id(),
                concert.title(),
                concert.genre(),
                imageStorage.getUrl(concert.posterImageKey()),
                concert.ageRating(),
                concert.status(),
                concert.viewCount(),
                concert.startDate(),
                concert.endDate(),
                concert.openAt(),
                concert.venueId(),
                concert.venueName());
    }

    private ConcertDetailResponseDto toDetail(ConcertFixture concert) {
        return new ConcertDetailResponseDto(
                concert.id(),
                concert.title(),
                concert.genre(),
                imageStorage.getUrl(concert.posterImageKey()),
                imageUrls(concert),
                concert.description(),
                concert.ageRating(),
                concert.status(),
                concert.viewCount(),
                concert.startDate(),
                concert.endDate(),
                concert.openAt(),
                concert.venueId(),
                concert.venueName(),
                concert.artistIds().stream()
                        .map(this::artist)
                        .map(artist -> new ConcertDetailResponseDto.ArtistSummary(
                                artist.id(), artist.name(), imageStorage.getUrl(artist.profileImageKey())))
                        .toList());
    }

    private CommandConcertResponseDto toCommandResponse(ConcertFixture concert) {
        return new CommandConcertResponseDto(
                concert.id(),
                concert.title(),
                concert.genre(),
                imageStorage.getUrl(concert.posterImageKey()),
                imageUrls(concert),
                concert.description(),
                concert.ageRating(),
                concert.status(),
                concert.viewCount(),
                concert.startDate(),
                concert.endDate(),
                concert.openAt(),
                concert.venueId(),
                concert.venueName(),
                concert.artistIds().stream()
                        .map(this::artist)
                        .map(artist -> new CommandConcertResponseDto.ArtistSummary(
                                artist.id(), artist.name(), imageStorage.getUrl(artist.profileImageKey())))
                        .toList());
    }

    private List<String> imageUrls(ConcertFixture concert) {
        return concert.imageKeys().stream().map(imageStorage::getUrl).toList();
    }

    /** 고정 아티스트가 아닌 id 는 이름을 만들어 채운다. 생성 요청의 임의 id 도 응답이 나가야 한다. */
    private ArtistFixture artist(long artistId) {
        ArtistFixture known = StubFixtures.ARTISTS.get(artistId);
        return known != null
                ? known
                : new ArtistFixture(artistId, "아티스트 " + artistId, "artist/" + artistId + "/profile.png");
    }
}
