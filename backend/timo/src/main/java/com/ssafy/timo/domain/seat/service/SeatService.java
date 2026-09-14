package com.ssafy.timo.domain.seat.service;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;

/**
 * 좌석 조회와 선점.
 *
 * <p>등록({@link #register})을 뺀 모든 메서드가 <b>공연 id 를 받는다.</b> 좌석은 공연장 마스터
 * 데이터라 공연을 빼고는 상태가 정해지지 않기 때문이다. 같은 좌석이라도 공연이 다르면 다른 자리다.
 *
 * <p>점유(결제 확정)·점유 해제는 없어졌다. 판매 상태는 이제 {@code seat} 행이 아니라
 * {@code reservation} 행이 갖는다. 예전의 {@code occupy} / {@code releaseOccupancy} 가 하던 일은
 * 주문을 만들고 취소하는 것으로 대체된다.
 */
public interface SeatService {

    /** 공연장의 구역과 좌석을 등록한다. 마스터 데이터라 공연과 무관하다. */
    CommandSeatResponseDto register(CommandSeatRequestDto request);

    /** 이 공연 기준의 구역 목록과 구역별 잔여석. */
    SectionListResponseDto findSections(Long concertId);

    /** 이 공연 기준의 구역 좌석 배치도. */
    SectionSeatListResponseDto findSeats(Long concertId, Long sectionId);

    /**
     * 이 공연의 좌석을 선점한다.
     *
     * <p>같은 좌석에 대한 동시 요청은 {@code seat_hold} 의 유니크 제약이 가른다. 좌석 행을 잠그지
     * 않으므로 <b>다른 공연의 선점 요청과 서로를 기다리지 않는다.</b>
     */
    SeatHoldResponseDto hold(Long concertId, Long seatId);

    /** 이 공연의 좌석 선점을 취소한다. */
    SeatHoldCancelResponseDto cancelHold(Long concertId, Long seatId);

    /**
     * 이 공연의 남은 좌석 수.
     *
     * <p>공연 상태 전이(잔여 0 이면 매진)가 쓰는 접점이라 시그니처를 바꾸지 않는다.
     */
    long countAvailable(Long concertId);
}
