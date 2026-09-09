package com.ssafy.timo.domain.seat.service;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatOccupancyResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;

public interface SeatService {
    CommandSeatResponseDto register(CommandSeatRequestDto request);

    SectionListResponseDto findSections(Long venueId);

    SectionSeatListResponseDto findSeats(Long sectionId);

    SeatHoldResponseDto hold(Long seatId);

    SeatHoldCancelResponseDto cancelHold(Long seatId);

    /** 요청자의 선점을 점유(결제 확정)로 바꾼다. 요청자는 {@code CurrentMemberProvider} 가 알려 준다. */
    SeatOccupancyResponseDto occupy(Long seatId);

    /**
     * 회원의 선점을 점유(결제 확정)로 바꾼다.
     *
     * <p>예매·결제 도메인이 결제 성공 시점에 부르는 진입점이다. 회원을 명시적으로 받으므로
     * 요청 컨텍스트가 없는 곳(결제 콜백 등)에서도 쓸 수 있다.
     */
    SeatOccupancyResponseDto occupy(Long seatId, Long memberId);

    /** 요청자의 점유를 풀어 예매 가능으로 되돌린다. 요청자는 {@code CurrentMemberProvider} 가 알려 준다. */
    SeatOccupancyResponseDto releaseOccupancy(Long seatId);

    /**
     * 회원의 점유를 풀어 예매 가능으로 되돌린다.
     *
     * <p>예매 도메인이 예매 취소를 확정한 뒤 부르는 진입점이다. 환불·취소 수수료 같은 예매 규칙은
     * 여기서 보지 않는다. 좌석은 "누구의 점유를 풀 것인가"만 안다.
     */
    SeatOccupancyResponseDto releaseOccupancy(Long seatId, Long memberId);
}
