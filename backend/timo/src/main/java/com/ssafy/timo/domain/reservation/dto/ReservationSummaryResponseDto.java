package com.ssafy.timo.domain.reservation.dto;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.entity.ReservationStatus;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;

/**
 * 주문 목록 항목. 내 예매 목록 카드에 필요한 것만 담는다.
 *
 * <p>발행 추적 정보(tokenId, 시도 횟수, 실패 사유)는 상세({@link ReservationDetailResponseDto})에만 있다.
 */
public record ReservationSummaryResponseDto(
        Long id,
        Long concertId,
        String concertTitle,
        String posterImageUrl,
        LocalDateTime startDate,
        String venueName,
        String sectionName,
        int seatNo,
        int seatCol,
        long facePrice,
        ReservationStatus status,
        LocalDateTime createdAt
) {
    public static ReservationSummaryResponseDto from(Reservation reservation, ImageStorage imageStorage) {
        Concert concert = reservation.getConcert();
        Seat seat = reservation.getSeat();

        return new ReservationSummaryResponseDto(
                reservation.getId(),
                concert.getId(),
                concert.getTitle(),
                imageStorage.getUrl(concert.getPosterImageKey()),
                concert.getStartDate(),
                concert.getVenue().getName(),
                seat.getSection().getName(),
                seat.getSeatNo(),
                seat.getSeatCol(),
                seat.getSection().getPrice(),
                reservation.getStatus(),
                reservation.getCreatedAt());
    }
}
