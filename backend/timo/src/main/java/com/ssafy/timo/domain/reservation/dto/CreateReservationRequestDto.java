package com.ssafy.timo.domain.reservation.dto;

import jakarta.validation.constraints.NotNull;

/**
 * 주문 확정 요청.
 *
 * <p>요청자는 본문이 아니라 {@code CurrentMemberProvider} 가 알려 준다. 결제 수단도 받지 않는다. 결제는
 * 예치 잔액 차감 한 가지뿐이다.
 *
 * <p>{@code concertId} 를 함께 받는 이유: 좌석은 공연장에 속하므로 좌석 id 만으로는 어느 공연의 표인지
 * 정해지지 않는다. 한 공연장에 동시 예매 중인 공연이 둘 이상이면 좌석 하나가 두 공연에 걸린다.
 */
public record CreateReservationRequestDto(

        @NotNull(message = "공연 ID는 필수입니다.")
        Long concertId,

        @NotNull(message = "좌석 ID는 필수입니다.")
        Long seatId
) {
}
