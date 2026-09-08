package com.ssafy.timo.domain.concert.dto;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;

/**
 * 목록 카드 한 장에 필요한 만큼만 담은 공연 요약.
 *
 * <p>출연 아티스트와 상세 이미지는 넣지 않는다. 둘 다 컬렉션이라 목록 조회에서 같이 읽으려면
 * 공연 수만큼 쿼리가 더 나가거나(N+1), 한 쿼리에 fetch join 하면 페이지 크기가 어긋난다
 * (컬렉션을 fetch join 하면 행이 늘어나 DB 에서 limit 을 걸 수 없다). 카드에는 대표 포스터와
 * 공연장 이름만 있으면 되고, 나머지는 상세 조회에서 내려간다.
 *
 * <p>페이지 정보는 여기서 다루지 않는다. 목록 응답은 이 요약을
 * {@link org.springframework.data.web.PagedModel} 로 감싸 내보낸다.
 *
 * <p>{@code posterImageUrl} 은 포스터가 없는 공연이면 {@code null} 이다.
 */
public record ConcertSummaryResponseDto(
        Long id,
        String title,
        ConcertGenre genre,
        String posterImageUrl,
        AgeRating ageRating,
        ConcertStatus status,
        int viewCount,
        LocalDateTime startDate,
        LocalDateTime endDate,
        LocalDateTime openAt,
        Long venueId,
        String venueName
) {

    public static ConcertSummaryResponseDto from(Concert concert, ImageStorage imageStorage) {
        return new ConcertSummaryResponseDto(
                concert.getId(),
                concert.getTitle(),
                concert.getGenre(),
                imageStorage.getUrl(concert.getPosterImageKey()),
                concert.getAgeRating(),
                concert.getStatus(),
                concert.getViewCount(),
                concert.getStartDate(),
                concert.getEndDate(),
                concert.getOpenAt(),
                concert.getVenue().getId(),
                concert.getVenue().getName()
        );
    }
}
