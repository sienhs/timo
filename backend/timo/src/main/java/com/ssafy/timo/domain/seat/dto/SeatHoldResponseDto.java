package com.ssafy.timo.domain.seat.dto;

import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatHold;
import com.ssafy.timo.domain.seat.entity.SeatStatus;

import java.time.LocalDateTime;

/**
 * 좌석 선점 응답.
 *
 * <p>{@code expiresAt} 을 반드시 내려준다. 화면이 남은 시간을 세려면 만료 시각을 알아야 하고,
 * 서버가 정한 시각을 그대로 쓰게 해야 클라이언트가 5 분을 따로 계산하다 어긋나는 일이 없다.
 *
 * <p>{@code status} 는 언제나 {@link SeatStatus#HELD} 다. 선점이 성공했다는 것이 곧 그 뜻이다.
 *
 * <p>선점한 회원 id 는 담지 않는다. 요청자 본인이므로 알려 줄 것이 없고, 좌석을 찔러 남의 선점
 * 현황을 읽어 내는 통로가 되면 안 된다.
 *
 * <p>{@code price} 를 함께 내려준다. 선점 다음은 결제 화면이고 거기서 금액을 보여 줘야 하는데,
 * 배치도 응답에서 받은 값을 화면 사이로 들고 다니게 하면 <b>어느 구역의 가격인지 어긋날 수 있다.</b>
 * 잡은 자리의 가격을 그 자리에서 함께 주면 그 어긋남이 생기지 않는다. 좌석이 아니라 구역의 값이다 —
 * 같은 구역이면 모든 자리가 같은 가격이다.
 */
public record SeatHoldResponseDto(
        Long seatId,
        Long sectionId,
        String sectionName,
        int seatNo,
        int seatCol,
        SeatStatus status,
        int price,
        LocalDateTime expiresAt,
        Long releasedSeatId
) {

    /**
     * @param releasedSeatId 이번 선점 때문에 함께 풀린 이전 선점 좌석. 없으면 {@code null}.
     *                       한 계정은 한 공연에서 좌석 하나만 잡을 수 있어, 새로 잡으면 이전 자리가
     *                       풀린다. 화면이 그 자리를 다시 그리려면 어디가 풀렸는지 알아야 한다.
     */
    public static SeatHoldResponseDto from(Seat seat, SeatHold hold, Long releasedSeatId) {
        return new SeatHoldResponseDto(
                seat.getId(),
                seat.getSection().getId(),
                seat.getSection().getName(),
                seat.getSeatNo(),
                seat.getSeatCol(),
                SeatStatus.HELD,
                seat.getSection().getPrice(),
                hold.getExpiresAt(),
                releasedSeatId);
    }
}
