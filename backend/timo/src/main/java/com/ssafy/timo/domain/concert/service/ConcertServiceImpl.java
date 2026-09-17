package com.ssafy.timo.domain.concert.service;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.exception.ArtistNotFoundException;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertDetailResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertListRequestDto;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.exception.InvalidConcertPeriodException;
import com.ssafy.timo.domain.concert.exception.InvalidTicketOpenTimeException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.concert.view.ViewCountStore;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.function.Function;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Transactional
public class ConcertServiceImpl implements ConcertService {

    private final ConcertRepository concertRepository;
    private final ViewCountStore viewCountStore;
    private final VenueRepository venueRepository;
    private final ArtistRepository artistRepository;
    private final SectionRepository sectionRepository;
    private final ImageStorage imageStorage;

    @Override
    public CommandConcertResponseDto create(CommandConcertRequestDto request) {
        validateSchedule(request);

        // 응답에 공연장 이름을 실어야 해서 참조만 만드는 대신 실제로 조회한다.
        Venue venue = venueRepository.findById(request.venueId())
                .orElseThrow(() -> new VenueNotFoundException(request.venueId()));

        Concert concert = Concert.builder()
                .title(request.title())
                .genre(request.genre())
                .posterImageKey(request.posterImageKey())
                .description(request.description())
                .ageRating(request.ageRating())
                .startDate(request.startDate())
                .endDate(request.endDate())
                .openAt(request.openAt())
                .venue(venue)
                .build();

        findArtistsInRequestedOrder(request.artistIds()).forEach(concert::addArtist);
        request.imageKeysOrEmpty().forEach(concert::addImage);

        return CommandConcertResponseDto.from(concertRepository.save(concert), imageStorage);
    }

    /**
     * 상태(취소·종료 포함)와 무관하게 조회할 수 있다 — 취소·종료된 공연도 상세 페이지는 남는다.
     *
     * <p>조회수 증가분은 DB 행을 갱신하지 않고 {@link ViewCountStore}에 기록한다. 따라서 같은
     * 공연으로 조회가 몰려도 DB update 락 경합이 생기지 않는다. 현재는 애플리케이션 메모리를 쓰며,
     * 다중 인스턴스가 필요해지면 Redis 구현체로 교체할 수 있다.
     */
    @Override
    @Transactional(readOnly = true)
    public ConcertDetailResponseDto find(Long concertId) {
        Concert concert = concertRepository.findByIdWithVenue(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));
        int viewCount = viewCountStore.incrementAndGet(concertId, concert.getViewCount());

        // 구역은 공연이 아니라 공연장에 속한다. 좌석을 아직 등록하지 않은 공연장이면 빈 목록이다.
        return ConcertDetailResponseDto.from(
                concert,
                sectionRepository.findAllByVenueIdOrderByIdAsc(concert.getVenue().getId()),
                imageStorage,
                viewCount);
    }

    /**
     * 조건에 맞는 공연 목록을 페이지 단위로 조회한다.
     *
     * <p>상세 조회와 달리 조회수를 올리지 않는다. 목록에 스쳐 지나간 것까지 조회로 세면
     * "인기 공연" 정렬이 목록에 오래 노출된 순서를 따라가 버린다. 그래서 읽기 전용이다.
     *
     * <p>{@link PagedModel} 로 감싸 내보낸다. {@code Page} 를 그대로 직렬화하면 {@code pageable.offset}
     * 처럼 클라이언트가 쓸 일 없는 내부 필드가 노출되고 구현에 따라 모양이 바뀌는데, 이 타입은
     * 그 문제를 피하려고 Spring Data 가 제공하는 응답 전용 타입이다.
     */
    @Override
    @Transactional(readOnly = true)
    public PagedModel<ConcertSummaryResponseDto> findAll(ConcertListRequestDto request) {
        return new PagedModel<>(concertRepository.findPage(
                        request.genre(),
                        request.status(),
                        request.keywordOrNull(),
                        request.toPageable())
                .map(concert -> ConcertSummaryResponseDto.from(concert, imageStorage)));
    }

    /**
     * 요청에 담긴 순서대로 아티스트를 조회한다.
     *
     * <p>같은 아티스트가 여러 번 들어오면 첫 번째만 남긴다. {@code concert_artist} 에 유니크 제약이 걸려 있어
     * 그대로 두면 커밋 시점에 500 이 되기 때문이다.
     */
    private List<Artist> findArtistsInRequestedOrder(List<Long> artistIds) {
        List<Long> distinctIds = List.copyOf(new LinkedHashSet<>(artistIds));

        Map<Long, Artist> found = artistRepository.findAllById(distinctIds).stream()
                .collect(Collectors.toMap(
                        Artist::getId, Function.identity(), (a, b) -> a, LinkedHashMap::new));

        return distinctIds.stream()
                .map(id -> {
                    Artist artist = found.get(id);
                    if (artist == null) {
                        throw new ArtistNotFoundException(id);
                    }
                    return artist;
                })
                .toList();
    }

    /** 일정은 모두 선택값이므로, 두 값이 함께 들어온 경우에만 선후 관계를 본다. */
    private void validateSchedule(CommandConcertRequestDto request) {
        if (request.startDate() != null && request.endDate() != null
                && request.endDate().isBefore(request.startDate())) {
            throw new InvalidConcertPeriodException();
        }

        if (request.openAt() != null && request.startDate() != null
                && request.openAt().isAfter(request.startDate())) {
            throw new InvalidTicketOpenTimeException();
        }
    }
}
