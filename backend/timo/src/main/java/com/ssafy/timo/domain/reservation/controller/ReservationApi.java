package com.ssafy.timo.domain.reservation.controller;

import com.ssafy.timo.domain.reservation.dto.CreateReservationRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationDetailResponseDto;
import com.ssafy.timo.domain.reservation.dto.ReservationListRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationSummaryResponseDto;
import jakarta.validation.Valid;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

/**
 * 예매(주문) API 규약.
 *
 * <p>메서드 매핑과 요청 검증 애노테이션은 여기에만 둔다. 구현체(v1 실제 컨트롤러, v0 스텁)는
 * 클래스 레벨 {@code @RequestMapping} 으로 버전 경로만 정하고 이 메서드들을 그대로 오버라이드한다.
 * 자세한 이유는 {@link com.ssafy.timo.domain.venue.controller.VenueApi} 참고.
 *
 * <p>v1 실제 구현은 아직 없다. 설계는 {@code backend/docs/BE_RESERVATION_DOMAIN_DRAFT.md} 참고.
 *
 * <p>취소는 주문 단위로 여기서 받는다. 회수({@code revoke})·환원·승계 재발급은 그 뒤에 이어지는 처리다.
 */
public interface ReservationApi {

    /**
     * 선점 중인 좌석으로 주문을 확정한다.
     *
     * <p>좌석 배정과 잔액 차감은 이 요청 안에서 끝나고 온체인 발행은 비동기다. 그래서 응답은 201 이지만
     * 상태는 {@code PENDING_MINT} 이며, 화면은 {@link #find(Long)} 로 발행 완료를 확인한다.
     *
     * <p>요청자가 유효하게 선점한 좌석이어야 한다. 선점이 없거나 만료됐으면 409, 남의 선점이면 403 이다.
     * 같은 공연의 유효한 주문이 이미 있으면 409({@code AlreadyReservedException}),
     * 공연이 예매 진행 중이 아니면 409({@code ConcertNotOnSaleException}) 다.
     */
    @PostMapping
    ResponseEntity<ReservationDetailResponseDto> create(@Valid @RequestBody CreateReservationRequestDto request);

    /** 내 주문 목록. 최근 주문순. {@code status} 로 걸러 볼 수 있다. */
    @GetMapping
    ResponseEntity<PagedModel<ReservationSummaryResponseDto>> findAll(
            @Valid @ModelAttribute ReservationListRequestDto request);

    /**
     * 주문 상세와 발행 진행 상태. "회원은 발행 진행 상태를 조회할 수 있다" 가 이 엔드포인트다.
     *
     * <p>남의 주문은 존재를 알리지 않고 404 다.
     */
    @GetMapping("/{reservationId}")
    ResponseEntity<ReservationDetailResponseDto> find(@PathVariable Long reservationId);

    /**
     * 예매를 취소한다. 티켓은 회수({@code REVOKED})되고 정가가 전액 포인트로 환원된다. 수수료는 없다.
     *
     * <p>공연 시작 24시간 전까지만 성립한다. 그 뒤의 처분 경로는 양도뿐이다. 발행이 끝난({@code MINTED}) 주문만
     * 취소할 수 있고, 티켓이 양도 등록 중이거나 입장했으면 409 다.
     *
     * <p>회수된 좌석은 좌석 선택 화면에 다시 나오지 않는다. 승계 대기자가 있으면 정가로 자동 재발급되고,
     * 없으면 주최사가 재오픈할 때까지 미판매로 남는다.
     */
    @DeleteMapping("/{reservationId}")
    ResponseEntity<ReservationDetailResponseDto> cancel(@PathVariable Long reservationId);
}
