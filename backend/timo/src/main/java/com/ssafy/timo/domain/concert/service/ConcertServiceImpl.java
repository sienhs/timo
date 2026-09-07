package com.ssafy.timo.domain.concert.service;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.exception.ArtistNotFoundException;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.exception.InvalidConcertPeriodException;
import com.ssafy.timo.domain.concert.exception.InvalidTicketOpenTimeException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.exception.VenueNotFoundException;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
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
    private final VenueRepository venueRepository;
    private final ArtistRepository artistRepository;
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
