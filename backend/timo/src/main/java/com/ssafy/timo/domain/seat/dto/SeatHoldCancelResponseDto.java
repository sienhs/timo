package com.ssafy.timo.domain.seat.dto;

import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatStatus;

/**
 * 좌석 선점 취소 응답.
 *
 * <p>선점 응답({@link SeatHoldResponseDto})과 같은 좌석 식별 정보를 내려준다. 화면이 좌석 목록을
 * 다시 받지 않고도 풀린 자리를 바로 다시 그릴 수 있어야 한다.
 *
 * <p>{@code expiresAt} 과 {@code releasedSeatId} 는 없다. 취소 뒤에는 만료 시각이 의미가 없고,
 * 취소는 다른 좌석에 영향을 주지 않는다.
 *
 * <p>{@code status} 는 언제나 {@link SeatStatus#AVAILABLE} 이다. 취소가 성공했다는 것이
 * 곧 자리가 비었다는 뜻이다.
 */
public record SeatHoldCancelResponseDto(
        Long seatId,
        Long sectionId,
        String sectionName,
        int seatNo,
        int seatCol,
        SeatStatus status
) {

    public static SeatHoldCancelResponseDto from(Seat seat) {
        return new SeatHoldCancelResponseDto(
                seat.getId(),
                seat.getSection().getId(),
                seat.getSection().getName(),
                seat.getSeatNo(),
                seat.getSeatCol(),
                SeatStatus.AVAILABLE);
    }
}
