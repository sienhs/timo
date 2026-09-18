package com.ssafy.timo.domain.goods.dto;

import com.ssafy.timo.global.storage.ImageStorage;
import java.time.LocalDateTime;

/**
 * 굿즈를 만들 수 있는 공연 한 장(= 입장 완료한 내 티켓 한 장).
 *
 * <p>{@link #ticketId} 가 주 식별자다. 굿즈는 공연이 아니라 <b>티켓</b>에 붙기 때문이고, 생성 API 가
 * 받는 값도 그쪽이다. {@link #goodsId} 가 있으면 이미 만든 공연이라 화면이 배지를 달거나 상세로 보낸다.
 *
 * <p>{@link #videoUrl} 은 지금 항상 {@code null} 이다. 공연에 영상 컬럼이 없다. 컬럼이 생기면
 * {@code CollectibleConcertRow} 와 조회 쿼리에 함께 붙인다.
 */
public record CollectibleConcertResponseDto(
        Long ticketId,
        Long concertId,
        String title,
        String artist,
        LocalDateTime date,
        String venue,
        String thumbnailUrl,
        String videoUrl,
        Long goodsId
) {

    public static CollectibleConcertResponseDto from(CollectibleConcertRow row, ImageStorage imageStorage) {
        return new CollectibleConcertResponseDto(
                row.getTicketId(),
                row.getConcertId(),
                row.getTitle(),
                row.getArtist(),
                row.getStartDate(),
                row.getVenue(),
                imageStorage.getUrl(row.getPosterImageKey()),
                null,
                row.getGoodsId());
    }
}
