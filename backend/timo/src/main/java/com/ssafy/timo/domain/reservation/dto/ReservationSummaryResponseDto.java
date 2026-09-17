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
 *
 * <p>{@code ticketId}는 발행 추적 정보가 아니라서 목록에도 싣는다. 주문과 같은 트랜잭션에서 만들어져
 * 발행 전에도 값이 있고, <b>양도 등록 화면이 고를 티켓을 이 목록에서 만들기 때문에</b> 여기 없으면
 * 앱이 등록 요청을 조립할 수 없다. 주문 식별자({@code id})와는 다른 값이다.
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
        Long ticketId,
        LocalDateTime createdAt
) {
    /**
     * {@code ticketId}를 밖에서 받는 이유는 {@link Reservation}이 티켓을 가리키지 않기 때문이다.
     * 연관은 {@code Ticket -> Reservation} 단방향이라 예매만 쥐고는 알 수 없고, 목록 조회가 페이지
     * 단위로 한 번에 모아 온 값을 넘겨준다({@code ReservationServiceImpl.findAll}).
     *
     * <p>역방향 연관({@code @OneToOne(mappedBy)})을 걸지 않은 것은 의도다 - 그쪽은 LAZY가 듣지 않아
     * ({@code null} 여부를 알아야 프록시를 만들 수 있다) 예매를 읽는 모든 경로에 티켓 조회가 따라붙는다.
     */
    public static ReservationSummaryResponseDto from(Reservation reservation, Long ticketId, ImageStorage imageStorage) {
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
                ticketId,
                reservation.getCreatedAt());
    }
}
