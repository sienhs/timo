package com.ssafy.timo.domain.transfer.controller;

import com.ssafy.timo.domain.transfer.dto.CreateListingRequestDto;
import com.ssafy.timo.domain.transfer.dto.ListingDetailResponseDto;
import com.ssafy.timo.domain.transfer.dto.ListingSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MarketConcertSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MarketListRequestDto;
import com.ssafy.timo.domain.transfer.dto.MyTradeSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseRequestDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseResponseDto;
import com.ssafy.timo.domain.transfer.dto.UpdateListingPriceRequestDto;
import com.ssafy.timo.domain.transfer.service.ListingService;
import com.ssafy.timo.domain.transfer.service.MarketQueryService;
import com.ssafy.timo.domain.transfer.service.PurchaseService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;

/**
 * 공식 양도 마켓 API (v1, 실제 구현).
 *
 * <p>엔드포인트 매핑과 검증 규약은 {@link MarketApi} 에 있다. 이 클래스는 버전 경로를 정하고
 * 서비스에 위임만 한다. 프론트 연동용 스텁은 {@code /api/v0/market} 에 같은 규약으로 떠 있다.
 *
 * <p>서비스가 셋으로 나뉜 이유는 트랜잭션 성격이 다르기 때문이다 — 조회는 읽기 전용이고,
 * 등록·취소는 매물의 생명주기를 다루며, 체결은 조건부 UPDATE 로 선착순을 가린다.
 *
 * <p>모든 경로가 인증을 요구한다. {@code SecurityConfig} 의 {@code anyRequest().authenticated()} 가
 * 받으므로 경로를 따로 등록하지 않는다 — permitAll 목록에 없으면 잠긴다.
 */
@RestController
@RequestMapping(MarketController.BASE_PATH)
@RequiredArgsConstructor
public class MarketController implements MarketApi {

    /** Location 헤더를 만들 때도 재사용하도록 상수로 둔다. */
    static final String BASE_PATH = "/api/v1/market";

    private final MarketQueryService marketQueryService;
    private final ListingService listingService;
    private final PurchaseService purchaseService;

    @Override
    public ResponseEntity<PagedModel<MarketConcertSummaryResponseDto>> findConcerts(
            MarketListRequestDto request, Long memberId) {
        return ResponseEntity.ok(marketQueryService.findConcerts(request));
    }

    @Override
    public ResponseEntity<PagedModel<ListingSummaryResponseDto>> findListings(
            Long concertId, MarketListRequestDto request, Long memberId) {
        return ResponseEntity.ok(marketQueryService.findListings(concertId, request, memberId));
    }

    @Override
    public ResponseEntity<ListingDetailResponseDto> findListing(Long listingId, Long memberId) {
        return ResponseEntity.ok(marketQueryService.findListing(listingId, memberId));
    }

    @Override
    public ResponseEntity<PagedModel<MyTradeSummaryResponseDto>> findMyTrades(
            MarketListRequestDto request, Long memberId) {
        return ResponseEntity.ok(marketQueryService.findMyTrades(request, memberId));
    }

    @Override
    public ResponseEntity<ListingDetailResponseDto> list(CreateListingRequestDto request, Long memberId) {
        ListingDetailResponseDto response = listingService.register(request, memberId);

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/listings/" + response.listingId()))
                .body(response);
    }

    @Override
    public ResponseEntity<ListingDetailResponseDto> updatePrice(
            Long listingId, UpdateListingPriceRequestDto request, Long memberId) {
        return ResponseEntity.ok(listingService.updatePrice(listingId, request, memberId));
    }

    @Override
    public ResponseEntity<Void> cancel(Long listingId, Long memberId) {
        listingService.cancel(listingId, memberId);

        return ResponseEntity.noContent().build();
    }

    /**
     * {@code 202} 다. 응답 시점에는 DB 상 체결만 끝났고 코인 전송·NFT 이전은 아직이다.
     *
     * <p>{@code Idempotency-Key} 는 규약상 필수라 형식을 검증하지만 <b>아직 저장하지 않는다.</b>
     * 이유는 {@link PurchaseService} 주석을 본다.
     */
    @Override
    public ResponseEntity<PurchaseResponseDto> purchase(
            Long listingId, String idempotencyKey, PurchaseRequestDto request, Long memberId) {
        return ResponseEntity.accepted().body(purchaseService.purchase(listingId, request, memberId));
    }
}
