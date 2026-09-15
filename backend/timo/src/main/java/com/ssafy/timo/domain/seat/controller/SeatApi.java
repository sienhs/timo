package com.ssafy.timo.domain.seat.controller;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;

/**
 * 좌석 API 규약.
 *
 * <p>메서드 매핑과 요청 검증 애노테이션은 여기에만 둔다. 구현체(v1 실제 컨트롤러, v0 스텁)는
 * 클래스 레벨 {@code @RequestMapping} 으로 버전 경로만 정하고 이 메서드들을 그대로 오버라이드한다.
 * 자세한 이유는 {@link com.ssafy.timo.domain.venue.controller.VenueApi} 참고.
 *
 * <p><b>조회와 선점은 {@code concertId} 를 반드시 받는다.</b> 좌석은 공연장에 속한 마스터 데이터라
 * 여러 공연이 같은 자리를 공유하고, 판매 여부는 공연마다 다르기 때문이다. 공연을 빼고 물으면
 * 어느 공연의 좌석표인지 정해지지 않는다.
 *
 * <p><b>선점·선점 취소는 요청자를 {@link CurrentMember} 로만 받는다.</b> 경로·쿼리·본문 어디에도
 * 회원 식별자를 두지 않아 남의 자리를 잡거나 푸는 요청을 만들 자체가 불가능하다. 그 값이 access
 * token 의 {@code sub} 에서만 온다는 것과, 요청자를 특정할 수 없을 때 401 이라는 것은 그 애노테이션의
 * 규약이다.
 *
 * <p>점유(결제 확정) 엔드포인트는 없어졌다. 판매 상태는 이제 좌석이 아니라 주문이 갖는다.
 */
public interface SeatApi {

    /**
     * 한 공연의 구역 하나에 대한 좌석 배치도를 행 -> 자리 순서로 조회한다.
     *
     * <p>좌석은 언제나 구역 단위로 조회한다. 공연장 전체 좌석은 수만 건이 될 수 있어 한 응답에 실을
     * 크기가 아니다. 구역 목록은 {@link SectionApi} 에서 받는다.
     *
     * <p>페이지로 나누지 않는다. 배치도는 좌석이 전부 있어야 그려진다.
     */
    @GetMapping
    ResponseEntity<SectionSeatListResponseDto> findSeats(@RequestParam Long concertId,
                                                         @RequestParam Long sectionId);

    /**
     * 이 공연의 좌석을 선점한다. 5 분 동안 다른 회원이 잡을 수 없다.
     *
     * <p>한 계정은 <b>한 공연에서</b> 좌석 하나만 잡을 수 있어, 새로 잡으면 그 공연의 이전 선점이
     * 함께 풀린다. 풀린 좌석은 응답의 {@code releasedSeatId} 로 알려 준다. 다른 공연의 선점은
     * 영향을 받지 않는다. 이미 내가 잡고 있는 좌석을 다시 부르면 만료 시각이 5 분 뒤로 갱신된다.
     *
     * <p>남이 잡고 있거나 이미 팔린 자리는 409 다.
     */
    @PostMapping("/{seatId}/hold")
    ResponseEntity<SeatHoldResponseDto> hold(@PathVariable Long seatId,
                                             @RequestParam Long concertId,
                                             @CurrentMember Long memberId);

    /**
     * 이 공연의 좌석 선점을 취소한다. 자리는 즉시 예매 가능으로 돌아간다.
     *
     * <p>이미 빈 자리를 취소해도 200 이다. 취소는 멱등하다. 남이 잡고 있거나 이미 팔린 좌석은
     * 403 으로 거절한다.
     */
    @DeleteMapping("/{seatId}/hold")
    ResponseEntity<SeatHoldCancelResponseDto> cancelHold(@PathVariable Long seatId,
                                                          @RequestParam Long concertId,
                                                          @CurrentMember Long memberId);

    /**
     * 공연장의 구역과 좌석을 등록한다. 마스터 데이터라 공연을 받지 않는다.
     *
     * <p>Location 헤더를 싣지 않는다. 한 번의 호출로 구역 여러 개와 좌석 수천 건이 만들어지므로
     * 가리킬 단일 리소스가 없다. 만들어진 구역은 응답 본문의 {@code sections} 에서 확인한다.
     */
    @PostMapping
    ResponseEntity<CommandSeatResponseDto> register(@Valid @RequestBody CommandSeatRequestDto request);
}
