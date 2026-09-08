package com.ssafy.timo.domain.seat.dto;

import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatStatus;

import java.time.LocalDateTime;

/**
 * 좌석 선점 응답.
 *
 * <p>{@code heldUntil} 을 반드시 내려준다. 화면이 남은 시간을 세려면 만료 시각을 알아야 하고,
 * 서버가 정한 시각을 그대로 쓰게 해야 클라이언트가 5 분을 따로 계산하다 어긋나는 일이 없다.
 *
 * <p>선점한 회원 id 는 담지 않는다. 요청자 본인이므로 알려 줄 것이 없고, 좌석을 찔러 남의 선점
 * 현황을 읽어 내는 통로가 되면 안 된다.
 */
public record SeatHoldResponseDto(
        Long seatId,
        Long sectionId,
        String sectionName,
        int seatNo,
        int seatCol,
        SeatStatus status,
        LocalDateTime heldUntil,
        Long releasedSeatId
) {

    /**
     * @param releasedSeatId 이번 선점 때문에 함께 풀린 이전 선점 좌석. 없으면 {@code null}.
     *                       한 계정은 좌석 하나만 잡을 수 있어, 새로 잡으면 이전 자리가 풀린다.
     *                       화면이 그 자리를 다시 그리려면 어디가 풀렸는지 알아야 한다.
     */
    public static SeatHoldResponseDto from(Seat seat, Long releasedSeatId) {
        return new SeatHoldResponseDto(
                seat.getId(),
                seat.getSection().getId(),
                seat.getSection().getName(),
                seat.getSeatNo(),
                seat.getSeatCol(),
                seat.getStatus(),
                seat.getHeldUntil(),
                releasedSeatId);
    }
}
