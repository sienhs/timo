package com.ssafy.timo.domain.concert.dto;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertImage;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 공연 단건 조회 응답.
 *
 * <p>저장된 것은 이미지 key 지만 클라이언트가 바로 쓸 수 있도록 {@link ImageStorage} 로 URL 을 만들어 내려준다.
 *
 * <p>{@code sectionPrices} 로 구역별 가격을 함께 준다. 상세 화면이 "가격 99,000원~" 같은 안내를
 * 그리려면 가격이 필요한데, 그것 하나 때문에 구역 목록 API 를 한 번 더 부르게 하지 않는다.
 * 지금은 구역마다 값이 같더라도 목록으로 준다 — <b>구역별로 가격이 갈리는 것이 원래 모양</b>이라,
 * 단일 값으로 주면 나중에 갈릴 때 응답 스키마가 바뀐다.
 *
 * <p>잔여석은 담지 않는다. 그건 공연을 고른 <b>다음</b> 구역 선택 화면의 관심사이고, 여기서 함께
 * 세면 상세 조회마다 좌석 집계 쿼리가 따라붙는다.
 */
public record ConcertDetailResponseDto(
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
        List<ArtistSummary> artists,
        List<SectionPrice> sectionPrices
) {

    public static ConcertDetailResponseDto from(Concert concert,
                                                List<Section> sections,
                                                ImageStorage imageStorage,
                                                int viewCount) {
        return new ConcertDetailResponseDto(
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
                viewCount,
                concert.getStartDate(),
                concert.getEndDate(),
                concert.getOpenAt(),
                concert.getVenue().getId(),
                concert.getVenue().getName(),
                concert.getArtists().stream()
                        .map(artist -> ArtistSummary.from(artist, imageStorage))
                        .toList(),
                sections.stream()
                        .map(SectionPrice::from)
                        .toList()
        );
    }

    /**
     * 구역 하나의 가격.
     *
     * <p>잔여석·격자 크기는 담지 않는다. 상세 화면이 쓰는 것은 가격뿐이고, 구역을 실제로 고르는
     * 화면은 {@code GET /api/v1/sections} 로 전체를 받아 간다.
     */
    public record SectionPrice(Long sectionId, String sectionName, int price) {

        static SectionPrice from(Section section) {
            return new SectionPrice(section.getId(), section.getName(), section.getPrice());
        }
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
