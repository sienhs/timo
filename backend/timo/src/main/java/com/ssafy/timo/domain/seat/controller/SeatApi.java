package com.ssafy.timo.domain.seat.controller;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatOccupancyResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;
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
 */
public interface SeatApi {

    /**
     * 구역 하나의 좌석을 배치도 순서(행 -> 자리)로 조회한다.
     *
     * <p>{@code sectionId} 는 필수다. 좌석은 언제나 구역 단위로 조회한다. 공연장 전체 좌석은
     * 수만 건이 될 수 있어 한 응답에 실을 크기가 아니다. 구역 목록은 {@link SectionApi} 에서 받는다.
     *
     * <p>페이지로 나누지 않는다. 배치도는 좌석이 전부 있어야 그려진다.
     */
    @GetMapping
    ResponseEntity<SectionSeatListResponseDto> findSeats(@RequestParam Long sectionId);

    /**
     * 좌석을 선점한다. 5 분 동안 다른 회원이 잡을 수 없다.
     *
     * <p>한 계정은 좌석 하나만 잡을 수 있어, 새로 잡으면 이전 선점이 함께 풀린다. 풀린 좌석은
     * 응답의 {@code releasedSeatId} 로 알려 준다. 이미 내가 잡고 있는 좌석을 다시 부르면
     * 만료 시각이 5 분 뒤로 갱신된다.
     */
    @PostMapping("/{seatId}/hold")
    ResponseEntity<SeatHoldResponseDto> hold(@PathVariable Long seatId);

    /**
     * 좌석 선점을 취소한다. 자리는 즉시 예매 가능으로 돌아간다.
     *
     * <p>이미 빈 자리를 취소해도 200 이다. 취소는 멱등하다. 남이 잡고 있거나 결제까지 끝난 좌석은
     * 403 으로 거절한다.
     */
    @DeleteMapping("/{seatId}/hold")
    ResponseEntity<SeatHoldCancelResponseDto> cancelHold(@PathVariable Long seatId);

    /**
     * 선점한 좌석을 점유(결제 확정)한다. 점유된 좌석은 만료되지 않고 예매 취소로만 풀린다.
     *
     * <p><b>임시 API 다.</b> 예매 도메인이 결제 확정을 처리하게 되면 이 엔드포인트를 삭제한다.
     * 유효한 내 선점 위에서만 200 이다. 선점이 없거나 만료됐으면 409, 남의 선점·점유면 403 이다.
     */
    @PostMapping("/{seatId}/occupancy")
    ResponseEntity<SeatOccupancyResponseDto> occupy(@PathVariable Long seatId);

    /**
     * 점유(결제 확정)를 풀어 좌석을 예매 가능으로 되돌린다.
     *
     * <p><b>임시 API 다.</b> 예매 도메인이 예매 취소를 처리하게 되면 이 엔드포인트를 삭제한다.
     * 이미 빈 자리를 풀어도 200 이다. 결제 전 선점 상태면 409, 남의 점유면 403 이다.
     */
    @DeleteMapping("/{seatId}/occupancy")
    ResponseEntity<SeatOccupancyResponseDto> releaseOccupancy(@PathVariable Long seatId);

    /**
     * 공연장의 구역과 좌석을 등록한다.
     *
     * <p>Location 헤더를 싣지 않는다. 한 번의 호출로 구역 여러 개와 좌석 수천 건이 만들어지므로
     * 가리킬 단일 리소스가 없다. 만들어진 구역은 응답 본문의 {@code sections} 에서 확인한다.
     */
    @PostMapping
    ResponseEntity<CommandSeatResponseDto> register(@Valid @RequestBody CommandSeatRequestDto request);
}
