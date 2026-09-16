package com.ssafy.timo.domain.reservation.controller;

import com.ssafy.timo.domain.reservation.dto.CreateReservationRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationDetailResponseDto;
import com.ssafy.timo.domain.reservation.dto.ReservationListRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationSummaryResponseDto;
import com.ssafy.timo.domain.reservation.service.ReservationService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 예매(주문) API (v1, 실제 구현).
 *
 * <p>엔드포인트 매핑과 검증 규약은 {@link ReservationApi} 에 있다. 이 클래스는 버전 경로를 정하고
 * 서비스에 위임만 한다. 프론트 연동용 스텁은 {@code /api/v0/reservations} 에 같은 규약으로 떠 있다.
 */
@RestController
@RequestMapping(ReservationController.BASE_PATH)
@RequiredArgsConstructor
public class ReservationController implements ReservationApi {

    static final String BASE_PATH = "/api/v1/reservations";

    private final ReservationService reservationService;

    @Override
    public ResponseEntity<ReservationDetailResponseDto> create(CreateReservationRequestDto request, Long memberId) {
        ReservationDetailResponseDto response = reservationService.create(memberId, request);

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    @Override
    public ResponseEntity<PagedModel<ReservationSummaryResponseDto>> findAll(ReservationListRequestDto request, Long memberId) {
        return ResponseEntity.ok(reservationService.findAll(memberId, request));
    }

    @Override
    public ResponseEntity<ReservationDetailResponseDto> find(Long reservationId, Long memberId) {
        return ResponseEntity.ok(reservationService.find(memberId, reservationId));
    }

    @Override
    public ResponseEntity<ReservationDetailResponseDto> cancel(Long reservationId, Long memberId) {
        return ResponseEntity.ok(reservationService.cancel(memberId, reservationId));
    }
}
