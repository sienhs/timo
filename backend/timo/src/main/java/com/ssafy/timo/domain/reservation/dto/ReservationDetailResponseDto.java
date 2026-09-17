package com.ssafy.timo.domain.reservation.dto;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.entity.ReservationStatus;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;

/**
 * 주문 상세. 주문 확정 응답과 진행 상태 조회 응답이 같은 모양이다.
 *
 * <p>{@code status}는 "이 자리가 팔렸는가"만 나타낸다({@link ReservationStatus} - PAID/CANCELLED).
 * 온체인 발행 진행 상태(대기·완료·실패·환불)는 {@code tokenId}·{@code mintTxHash}·
 * {@code mintAttemptCount}·{@code failureReason}로 따로 드러난다 - 전부 연결된
 * {@link Ticket}에서 가져온다.
 *
 * <p>{@code facePrice}는 이 좌석이 속한 {@link Section#getPrice()}다(구역마다 다름, 공연 전체
 * 단일가 아님). 단위는 아직 미확정이다 - 컨트랙트(={@code ShowRegistry}에 실리는 값)는 wei,
 * 여기 구역 가격은 원화 정수라 둘을 맞추는 결정이 남아 있다. 결정 전까지는 구역 정가를 원 단위
 * 그대로 싣는다.
 */
public record ReservationDetailResponseDto(
        Long id,
        String orderId,
        Long concertId,
        String concertTitle,
        String posterImageUrl,
        LocalDateTime startDate,
        String venueName,
        Long seatId,
        Long sectionId,
        String sectionName,
        int seatNo,
        int seatCol,
        long facePrice,
        ReservationStatus status,
        String tokenId,
        String mintTxHash,
        int mintAttemptCount,
        String failureReason,
        LocalDateTime createdAt,
        LocalDateTime updatedAt
) {
    public static ReservationDetailResponseDto from(Reservation reservation, Ticket ticket, ImageStorage imageStorage) {
        Concert concert = reservation.getConcert();
        Seat seat = reservation.getSeat();
        Section section = seat.getSection();

        return new ReservationDetailResponseDto(
                reservation.getId(),
                "reservation-" + reservation.getId(),
                concert.getId(),
                concert.getTitle(),
                imageStorage.getUrl(concert.getPosterImageKey()),
                concert.getStartDate(),
                concert.getVenue().getName(),
                seat.getId(),
                section.getId(),
                section.getName(),
                seat.getSeatNo(),
                seat.getSeatCol(),
                section.getPrice(),
                reservation.getStatus(),
                ticket.getTokenId() == null ? null : ticket.getTokenId().toString(),
                ticket.getMintTxHash(),
                ticket.getMintAttemptCount(),
                ticket.getFailureReason(),
                reservation.getCreatedAt(),
                reservation.getUpdatedAt());
    }
}
