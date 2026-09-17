package com.ssafy.timo.domain.concert.dto;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertImage;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 공연 생성 응답.
 *
 * <p>저장된 것은 이미지 key 지만 클라이언트가 바로 쓸 수 있도록 {@link ImageStorage} 로 URL 을 만들어 내려준다.
 */
public record CommandConcertResponseDto(
        Long id,
        String title,
        ConcertGenre genre,
        String posterImageUrl,
        List<String> imageUrls,
        String description,
        AgeRating ageRating,
        ConcertStatus status,
        int viewCount,
        LocalDateTime startDate,
        LocalDateTime endDate,
        LocalDateTime openAt,
        Long venueId,
        String venueName,
        List<ArtistSummary> artists
) {

    public static CommandConcertResponseDto from(Concert concert, ImageStorage imageStorage) {
        return new CommandConcertResponseDto(
                concert.getId(),
                concert.getTitle(),
                concert.getGenre(),
                imageStorage.getUrl(concert.getPosterImageKey()),
                concert.getImages().stream()
                        .map(ConcertImage::getImageKey)
                        .map(imageStorage::getUrl)
                        .toList(),
                concert.getDescription(),
                concert.getAgeRating(),
                concert.getStatus(),
                concert.getViewCount(),
                concert.getStartDate(),
                concert.getEndDate(),
                concert.getOpenAt(),
                concert.getVenue().getId(),
                concert.getVenue().getName(),
                concert.getArtists().stream()
                        .map(artist -> ArtistSummary.from(artist, imageStorage))
                        .toList()
        );
    }

    /**
     * 응답에 실리는 아티스트 요약.
     *
     * <p>저장된 것은 이미지 key 지만 클라이언트가 바로 쓸 수 있도록 {@link ImageStorage} 로 URL 을
     * 만들어 내려준다.
     */
    public record ArtistSummary(Long id, String name, String profileImageUrl) {

        static ArtistSummary from(Artist artist, ImageStorage imageStorage) {
            return new ArtistSummary(artist.getId(), artist.getName(),
                    imageStorage.getUrl(artist.getProfileImageKey()));
        }
    }
}
