package com.ssafy.timo.domain.offer.dto;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.offer.entity.CancelOffer;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;

/**
 * 내게 열린 취소표 구매 기회 한 건.
 *
 * <p>당첨자가 결제로 가는 데 필요한 값이 다 실린다 — 예매 API 가 받는 {@code concertId} 와 {@code seatId},
 * 화면이 보여 줄 좌석 위치와 정가. {@code price} 는 구역 정가라 예매 결제액과 같다.
 *
 * @param expiresAt 구매 기한. 앱은 목록의 {@code serverTime} 과의 차이로 남은 시간을 그린다
 */
public record CancelOfferSummaryResponseDto(
        Long offerId,
        Long concertId,
        String concertTitle,
        String posterImageUrl,
        LocalDateTime startDate,
        String venueName,
        Long seatId,
        String sectionName,
        int seatNo,
        int seatCol,
        long price,
        LocalDateTime expiresAt) {

    public static CancelOfferSummaryResponseDto from(CancelOffer offer, ImageStorage imageStorage) {
        Concert concert = offer.getConcert();
        Seat seat = offer.getSeat();
        return new CancelOfferSummaryResponseDto(
                offer.getId(),
                concert.getId(),
                concert.getTitle(),
                imageStorage.getUrl(concert.getPosterImageKey()),
                concert.getStartDate(),
                concert.getVenue().getName(),
                seat.getId(),
                seat.getSection().getName(),
                seat.getSeatNo(),
                seat.getSeatCol(),
                seat.getSection().getPrice(),
                offer.getExpiresAt());
    }
}
