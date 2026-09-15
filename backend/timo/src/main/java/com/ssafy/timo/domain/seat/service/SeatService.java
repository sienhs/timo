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
 * <p>선점과 선점 취소는 <b>요청자 id 를 첫 인자로 받는다.</b> 컨트롤러가
 * {@code @AuthenticationPrincipal} 로 받은 access token 에서 꺼내 넘겨 준다. 여기서 직접 꺼내지
 * 않는 이유는, 서비스가 HTTP 요청에 매달리면 배치나 다른 서비스가 부를 수 없기 때문이다.
 *
 * <p><b>넘어온 {@code memberId} 가 요청자 본인인지는 검사하지 않는다.</b> 토큰의 {@code sub}
 * 외의 값을 넘기면 남의 선점을 마음대로 풀 수 있으므로, 호출하는 쪽이 그 규약을 지켜야 한다.
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
     * <p>공연이 예매 중이 아니면(오픈 전·매진·종료·취소) 거절한다. 이 공연의 티켓을 이미 산
     * 회원이 다른 자리를 새로 선점하려는 것도 거절한다("1인 1매"). 이 공연에서 취소된 적이 있는
     * 자리("회수됨")도 재오픈 절차 전까지는 거절한다.
     *
     * <p>같은 좌석에 대한 동시 요청은 {@code seat_hold} 의 유니크 제약이 가른다. 좌석 행을 잠그지
     * 않으므로 <b>다른 공연의 선점 요청과 서로를 기다리지 않는다.</b>
     */
    SeatHoldResponseDto hold(Long memberId, Long concertId, Long seatId);

    /** 이 공연의 좌석 선점을 취소한다. 내 선점만 풀 수 있다. */
    SeatHoldCancelResponseDto cancelHold(Long memberId, Long concertId, Long seatId);

    /**
     * 이 공연의 남은 좌석 수.
     *
     * <p>공연 상태 전이(잔여 0 이면 매진)가 쓰는 접점이라 시그니처를 바꾸지 않는다.
     */
    long countAvailable(Long concertId);
}
