package com.ssafy.timo.domain.ticket.dto;

import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;

/**
 * 내가 지금 가진 티켓 한 장.
 *
 * <p>예매 목록 응답과 필드 이름을 맞췄다. 앱의 내 티켓 카드가 그동안 예매 목록으로 만들어져 있어
 * 갈아타는 비용을 줄이기 위해서다. 다만 주 식별자는 {@link #ticketId} 다 — 이 목록은 예매가 아니라
 * 티켓의 목록이고 양도 등록이 받는 값도 그쪽이다.
 *
 * <p>{@link #acquiredBy} 와 {@link #acquiredAt} 이 필요한 이유는, 양도받은 티켓의 예매 행은 판 사람
 * 것이라 그쪽 예매 시각을 내 화면에 "예매한 날" 로 찍으면 거짓말이 되기 때문이다.
 */
public record MyTicketSummaryResponseDto(
        Long ticketId,
        Long reservationId,
        Long concertId,
        String concertTitle,
        String posterImageUrl,
        LocalDateTime startDate,
        String venueName,
        String sectionName,
        int seatNo,
        int seatCol,
        long facePrice,
        TicketStatus ticketStatus,
        TicketAcquisition acquiredBy,
        LocalDateTime acquiredAt,
        boolean listed
) {

    public static MyTicketSummaryResponseDto from(MyTicketRow row, ImageStorage imageStorage) {
        return new MyTicketSummaryResponseDto(
                row.getTicketId(),
                row.getReservationId(),
                row.getConcertId(),
                row.getConcertTitle(),
                imageStorage.getUrl(row.getPosterImageKey()),
                row.getStartDate(),
                row.getVenueName(),
                row.getSectionName(),
                row.getSeatNo(),
                row.getSeatCol(),
                row.getFacePrice(),
                // 네이티브 조회라 enum 과 boolean 이 자동 변환되지 않는다. 여기서 옮긴다.
                TicketStatus.valueOf(row.getTicketStatus()),
                TicketAcquisition.valueOf(row.getAcquiredBy()),
                row.getAcquiredAt(),
                row.getListed() == 1);
    }
}
