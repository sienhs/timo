package com.ssafy.timo.domain.transfer.controller;

import com.ssafy.timo.domain.transfer.dto.CreateListingRequestDto;
import com.ssafy.timo.domain.transfer.dto.ListingListRequestDto;
import com.ssafy.timo.domain.transfer.dto.ListingResponseDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseResponseDto;
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
 * 공식 양도 마켓 API 규약.
 *
 * <p>양도는 이 마켓을 통해서만 이루어진다. 개인 간 직접 전송은 컨트랙트가 막는다. 매물은 {@code tokenId} 로
 * 식별한다. 티켓 하나는 동시에 매물 하나만 될 수 있어 별도 매물 id 가 필요 없다.
 *
 * <p>메서드 매핑과 요청 검증 애노테이션은 여기에만 둔다. 구현체(v1 실제 컨트롤러, v0 스텁)는
 * 클래스 레벨 {@code @RequestMapping} 으로 버전 경로만 정하고 이 메서드들을 그대로 오버라이드한다.
 * 자세한 이유는 {@link com.ssafy.timo.domain.venue.controller.VenueApi} 참고.
 *
 * <p>v1 실제 구현은 아직 없다. 등록·취소는 {@code TicketNFT.listForTransfer / delist}, 체결은
 * {@code Marketplace.buy} 를 백엔드 오퍼레이터 지갑이 대신 호출한다.
 */
public interface MarketApi {

    /**
     * 내 티켓을 양도 매물로 등록한다.
     *
     * <p>내가 보유한 티켓만, 정가 이하로만 등록된다. 등록되면 티켓은 {@code LISTED} 가 되어 취소·회수·입장이
     * 막힌다. 남의 티켓이면 403, 정가 초과면 400, 이미 등록 중이면 409 다.
     */
    @PostMapping("/listings")
    ResponseEntity<ListingResponseDto> list(@Valid @RequestBody CreateListingRequestDto request);

    /**
     * 등록을 취소한다. 티켓은 다시 보유 상태로 돌아간다. 204 다.
     *
     * <p><b>페널티 규칙은 미확정이다</b> (D-7 100% / 하루 80% / 당일 10% 중 미정). 정해지면 여기서 차감한다.
     */
    @DeleteMapping("/listings/{tokenId}")
    ResponseEntity<Void> delist(@PathVariable String tokenId);

    /**
     * 매물 목록. 낮은 가격순. {@code concertId} 로 공연 하나만 볼 수 있다.
     *
     * <p>내 매물도 함께 나오고 {@code mine} 으로 구분된다. 목록에서 내 것을 빼면 내가 올린 매물이 지금 어떤
     * 가격대에 놓여 있는지 알 수 없다.
     */
    @GetMapping("/listings")
    ResponseEntity<PagedModel<ListingResponseDto>> findAll(@Valid @ModelAttribute ListingListRequestDto request);

    /**
     * 매물을 구매한다. 대금 수령·소유 이전·판매자 정산이 한 번에 끝난다.
     *
     * <p>구매자에게도 1인 1매가 적용된다. 그 공연의 티켓을 이미 보유하고 있으면 409
     * ({@code AlreadyReservedException}) 다. 내 매물이면 409, 매물이 아니면 404 다.
     */
    @PostMapping("/listings/{tokenId}/purchase")
    ResponseEntity<PurchaseResponseDto> purchase(@PathVariable String tokenId);
}
