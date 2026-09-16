package com.ssafy.timo.domain.artist.dto;

import com.ssafy.timo.domain.artist.entity.Artist;

/**
 * 목록 카드 한 장에 필요한 만큼만 담은 아티스트 요약.
 *
 * <p>출연 공연은 넣지 않는다. 컬렉션이라 목록 조회에서 같이 읽으면 아티스트 수만큼 쿼리가 더
 * 나가거나(N+1), 한 쿼리에 fetch join 하면 행이 늘어 DB 에서 limit 을 걸 수 없다. 그 목록은
 * 아티스트 상세의 몫이다.
 *
 * <p>{@code profileImage} 는 아직 저장소 key 가 아니라 저장된 값 그대로다. 공연 상세의
 * {@code ConcertDetailResponseDto.ArtistSummary} 와 같은 취급이며, 아티스트 프로필까지 S3 로
 * 옮기면 두 곳을 함께 {@link com.ssafy.timo.global.storage.ImageStorage} 에 태운다.
 *
 * <p>페이지 정보는 여기서 다루지 않는다. 목록 응답은 이 요약을
 * {@link org.springframework.data.web.PagedModel} 로 감싸 내보낸다.
 */
public record ArtistSummaryResponseDto(
        Long id,
        String name,
        String profileImage
) {

    public static ArtistSummaryResponseDto from(Artist artist) {
        return new ArtistSummaryResponseDto(
                artist.getId(),
                artist.getName(),
                artist.getProfileImage()
        );
    }
}
