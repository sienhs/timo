package com.ssafy.timo.domain.seat.dto;

import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatStatus;

import java.time.LocalDateTime;

/**
 * 좌석 점유(결제 확정) / 점유 해제(예매 취소) 응답. 두 API 가 함께 쓴다.
 *
 * <p>선점 취소 응답({@link SeatHoldCancelResponseDto})과 같은 좌석 식별 정보를 내려준다.
 * {@code status} 로 점유인지 해제인지 구분한다 — 점유는 {@link SeatStatus#OCCUPIED},
 * 해제는 {@link SeatStatus#AVAILABLE}.
 *
 * <p>{@code heldUntil} 은 없다. 점유에는 만료가 없고, 해제 뒤에는 의미가 없다. 소유자 id 도 담지 않는다.
 * 요청자 본인이므로 알려 줄 것이 없다.
 */
public record SeatOccupancyResponseDto(
        Long seatId,
        Long sectionId,
        String sectionName,
        int seatNo,
        int seatCol,
        SeatStatus status
) {

    /**
     * @param now 기준 시각. 만료된 선점만 남은 좌석을 해제한 경우 {@code status} 컬럼이 아직
     *            RESERVED 일 수 있으므로 {@link Seat#effectiveStatus(LocalDateTime)} 로 실제 상태를 담는다.
     */
    public static SeatOccupancyResponseDto from(Seat seat, LocalDateTime now) {
        return new SeatOccupancyResponseDto(
                seat.getId(),
                seat.getSection().getId(),
                seat.getSection().getName(),
                seat.getSeatNo(),
                seat.getSeatCol(),
                seat.effectiveStatus(now));
    }
}
