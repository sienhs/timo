package com.ssafy.timo.domain.transfer.controller;

import com.ssafy.timo.domain.transfer.dto.CreateListingRequestDto;
import com.ssafy.timo.domain.transfer.dto.ListingDetailResponseDto;
import com.ssafy.timo.domain.transfer.dto.ListingSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MarketConcertSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MarketHoursResponseDto;
import com.ssafy.timo.domain.transfer.dto.MarketListRequestDto;
import com.ssafy.timo.domain.transfer.dto.MyTradeSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseRequestDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseResponseDto;
import com.ssafy.timo.domain.transfer.dto.TradeDetailResponseDto;
import com.ssafy.timo.domain.transfer.dto.UpdateListingPriceRequestDto;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;

/**
 * 공식 양도 마켓 API 규약.
 *
 * <p>양도는 이 마켓을 통해서만 이루어진다. 개인 간 직접 전송은 컨트랙트가 막는다.
 *
 * <p><b>매물은 {@code listingId} 로 식별한다.</b> 티켓 식별자({@code ticketId} · {@code tokenId})를
 * 외부에 내보내지 않기 위해서다. 노출되면 원 예매 건과 재양도 이력이 역추적되고, 특히
 * {@code tokenId} 는 온체인 공개값이라 체인 탐색기에서 소유 이력이 그대로 보인다. 한 티켓이
 * 여러 번 등록될 수 있으므로 매물마다 새 식별자가 생기는 편이 익명성에도 맞다.
 *
 * <p>모든 경로가 인증을 요구한다. {@code mine} 판정에 요청자가 필요하고, 요청자의 근거는
 * 서명된 토큰의 {@code sub} 하나뿐이다 — 경로·본문으로 회원 식별자를 받지 않는다. 그래서 요청자는
 * {@link CurrentMember} 로만 받는다({@code SeatApi} 와 같다).
 *
 * <p>메서드 매핑과 요청 검증 애노테이션은 여기에만 둔다. 구현체(v1 실제 컨트롤러, v0 스텁)는
 * 클래스 레벨 {@code @RequestMapping} 으로 버전 경로만 정하고 이 메서드들을 그대로 오버라이드한다.
 * 자세한 이유는 {@link com.ssafy.timo.domain.venue.controller.VenueApi} 참고.
 *
 * <p>v1 실제 구현은 아직 없다. 온체인 연동(등록은 {@code TicketNFT.listForTransfer},
 * 취소는 {@code delist}, 체결은 {@code Marketplace.buy})은 방식이 정해지지 않아
 * {@code TicketTransferService} 인터페이스 뒤로 미뤄 두었다.
 *
 * <p><b>{@code faceValue} 는 그 좌석이 속한 구역의 정가다</b>({@code Section.price}). 공연 전체
 * 단일가가 아니라 구역마다 다르며, 예매 응답의 {@code facePrice} 와 같은 값이다. 매물마다 등록
 * 시점의 값이 스냅샷으로 박혀 있어, 뒤에 구역 가격이 바뀌어도 이미 열린 매물의 상한은 그대로다.
 *
 * <p>금액 필드({@code price}, {@code faceValue}, {@code expectedPrice}, {@code lowestPrice})는
 * 모두 JSON 정수이며 서버에서 {@code long} 이다. 단위는 <b>아직 확정되지 않았다</b> — 컨트랙트는
 * wei, 백엔드 구역 가격은 원화 정수라 예매 API 도 같은 상태다. 앱은 이 값을 32비트 정수로
 * 받지 않는다.
 *
 * <p><b>마켓은 매일 정해진 시간에만 열린다</b>({@code market.hours}, 기본 08:00:00~23:00:00). 판정은
 * 서버 시계이며 앱은 {@link #hours} 로 받은 시각을 표시에만 쓴다.
 * <ul>
 *   <li>등록·취소·상세·내 내역: 시간 무관. 올린 매물은 <b>등록 다음 날 08:00</b> 에 목록에 한꺼번에 드러난다</li>
 *   <li>공연 목록·공연별 매물·구매: 창 안에서만, 그리고 올라온 매물만. 밖이면 409({@code MARKET_CLOSED}),
 *       아직 안 올라온 매물을 사면 409({@code LISTING_NOT_OPEN_YET})</li>
 *   <li>가격 수정: 창 <b>밖</b>에서만. 안이면 409({@code MARKET_OPEN}) — 거래 중 가격은 고정이다</li>
 * </ul>
 */
public interface MarketApi {

    /**
     * 지금 마켓이 열려 있는지와 창의 시각.
     *
     * <p>열려 있으면 이번 창, 닫혀 있으면 다음 창의 {@code opensAt}·{@code closesAt} 를 준다. 앱은
     * 자기 시계가 아니라 {@code serverTime} 을 기준으로 남은 시간을 그린다. 이 값으로 화면을
     * 잠그는 것은 안내일 뿐이고, 실제 차단은 등록·수정·구매가 각자 한다.
     */
    @GetMapping("/hours")
    ResponseEntity<MarketHoursResponseDto> hours(@CurrentMember Long memberId);

    /**
     * 양도 매물이 올라와 있는 공연 목록.
     *
     * <p>공연마다 매물 수와 최저가만 준다. 개별 매물은 {@link #findListings} 에서 받는다.
     * {@code LISTED} 매물이 없거나 이미 시작한 공연은 나오지 않는다.
     *
     * <p>정렬은 공연 시작일 오름차순이다. 티켓은 공연이 끝나면 가치가 없어 임박한 것부터가
     * 유일하게 의미 있는 순서다.
     *
     * <p>운영 시간 밖이면 409 다. 등록 다음 날부터의 매물만 세므로, 오늘 등록된 매물은 창이 열려도
     * 여기 잡히지 않는다 — 그 규칙이 곧 "다음 날 08:00 에 일괄로 올라간다" 다.
     */
    @GetMapping("/concerts")
    ResponseEntity<PagedModel<MarketConcertSummaryResponseDto>> findConcerts(
            @Valid @ModelAttribute MarketListRequestDto request,
            @CurrentMember Long memberId);

    /**
     * 공연 하나의 매물 목록. 낮은 가격순이다.
     *
     * <p>매물은 정가 이하로만 등록되므로 구매자에게 의미 있는 순서가 그것이다. 동가는 마지막에
     * 유일 키({@code listingId} 오름차순)를 덧붙여 페이지를 넘길 때 같은 매물이 두 번 나오지 않게 한다.
     *
     * <p>내 매물도 함께 나오고 {@code mine} 으로 구분된다. 목록에서 내 것을 빼면 내가 올린 매물이
     * 지금 어떤 가격대에 놓여 있는지 알 수 없다.
     *
     * <p>공연이 없으면 404 지만, 공연이 있고 매물만 없으면 빈 목록으로 200 이다. 운영 시간 밖이면
     * 공연 유무보다 먼저 409 다.
     */
    @GetMapping("/concerts/{concertId}/listings")
    ResponseEntity<PagedModel<ListingSummaryResponseDto>> findListings(
            @PathVariable Long concertId,
            @Valid @ModelAttribute MarketListRequestDto request,
            @CurrentMember Long memberId);

    /**
     * 매물 한 건의 상세.
     *
     * <p>팔렸거나 취소된 매물도 200 으로 조회된다. 목록에서 상세로 들어가는 사이에 팔릴 수 있고,
     * 그때 404 를 주면 화면이 "없는 매물"로 오해한다. 구매 가능 여부는 {@code status} 로 판단한다.
     */
    @GetMapping("/listings/{listingId}")
    ResponseEntity<ListingDetailResponseDto> findListing(@PathVariable Long listingId,
                                                        @CurrentMember Long memberId);

    /**
     * 거래 한 건의 상세. 판매 완료 알림이 가리키는 화면이고, 구매 완료 화면의 상태 확인도 여기로 한다.
     *
     * <p><b>판매자와 구매자만 본다.</b> 남의 거래는 없는 거래와 같은 404 다 — 거래는 두 사람만의 기록이라
     * 존재 여부도 알려 주지 않고, 번호가 순차라 403 으로 가르면 체결 건수가 샌다. {@code role} 이 요청자의
     * 입장(SELLER/BUYER)이며 상대가 누구인지는 어느 쪽에도 나오지 않는다. 운영 시간과 무관하다.
     */
    @GetMapping("/trades/{tradeId}")
    ResponseEntity<TradeDetailResponseDto> findTrade(@PathVariable Long tradeId,
                                                    @CurrentMember Long memberId);

    /**
     * 내 거래 내역. 판매와 구매를 한 목록에 섞어 최신순으로 준다.
     *
     * <p>경로를 둘로 나누면 "내 거래 내역" 화면 하나가 두 번 호출하고 시간순 병합을 클라이언트가
     * 해야 한다. 쿼리 파라미터로 나눠도 서버는 결국 같은 두 테이블을 합쳐야 하면서 분기만 는다.
     */
    @GetMapping("/listings/me")
    ResponseEntity<PagedModel<MyTradeSummaryResponseDto>> findMyTrades(
            @Valid @ModelAttribute MarketListRequestDto request,
            @CurrentMember Long memberId);

    /**
     * 내 티켓을 양도 매물로 등록한다. 201 이다.
     *
     * <p>내가 보유한 티켓만, 정가 이하로만 등록된다. 정가 기준은 공연 전체 단일가가 아니라 그 좌석이
     * 속한 <b>구역</b>의 가격({@code Section.price}) 이며, 등록 시점의 값이 매물에 스냅샷으로 남는다.
     * 예매 결제와 환불도 같은 기준이다. 등록되면 티켓은
     * {@code LISTED} 가 되어 취소·회수·입장이 막힌다 — 예매 취소는 이미 티켓이 {@code OWNED} 일
     * 때만 성립하므로({@code ReservationServiceImpl.cancel}) 등록 중인 티켓은 취소되지 않는다.
     *
     * <p>남의 티켓이면 403, 정가 초과면 400, 이미 등록 중이면 409 다.
     *
     * <p>운영 시간과 무관하게 받는다. 올린 매물은 {@code LISTED} 로 저장되고 남에게는 <b>등록 다음 날
     * 08:00</b> 부터 보인다 — 열린 시간에 올려도 그날은 안 보인다. 앱은 등록일 다음 날의 여는 시각을 안내한다.
     */
    @PostMapping("/listings")
    ResponseEntity<ListingDetailResponseDto> list(@Valid @RequestBody CreateListingRequestDto request,
                                                  @CurrentMember Long memberId);

    /**
     * 등록가를 바꾼다. 매물을 올린 <b>판매자 본인만</b> 할 수 있다. 200 이고 응답은 상세와 같은 모양이다.
     *
     * <p>취소하고 다시 올리는 것으로 갈음하지 않는 이유는 그러면 {@code listingId} 가 새로 생기기
     * 때문이다. 판매자에게는 "가격만 내린 같은 매물" 인데 식별자가 바뀌면 재양도 이력이
     * 끊어져 보이고, 앱도 상세 화면을 다시 열어야 한다.
     *
     * <p>{@code POST} 가 아니라 {@code PATCH} 인 이유는 <b>재시도가 안전해야 하기 때문이다.</b>
     * 취소({@link #cancel})는 되돌릴 수 없는 전이라 한 번만 일어나야 하지만, 가격 수정은 절댓값을
     * 넣는 것이라 같은 요청이 두 번 도착해도 결과가 같다. 모바일에서 응답을 받기 전에 끊기는 일이
     * 흔해 이 차이가 실제로 쓰인다. 이 API 에서 {@code PATCH} 를 쓰는 곳은 여기 하나다.
     *
     * <p>바꿀 수 있는 값은 가격뿐이다. 새 가격도 등록 때와 같은 규칙을 받는다 - <b>등록 시점에
     * 스냅샷으로 잡힌 정가</b>({@code ticket_listing.face_value}) 이하여야 한다. 구역 가격이 그 뒤에
     * 바뀌었더라도 기준은 스냅샷이다. 올리는 방향도 정가 이하이면 허용한다.
     *
     * <p><b>운영 시간 중에는 409({@code MARKET_OPEN})다.</b> 거래가 열려 있는 동안 가격은 고정이고,
     * 마감 뒤에 바꾼 가격이 다음 창에 올라간다. 그 밖에 남의 매물이면 403, 정가 초과면 400, 이미 팔렸거나
     * 취소된 매물이면 409, 매물이 없으면 404 다.
     *
     * <p><b>구매자가 보던 가격이 바뀌는 문제는 체결 쪽이 막는다.</b> 구매 요청은
     * {@code expectedPrice} 를 함께 보내고, 그 값이 등록가와 다르면 409
     * ({@code LISTING_PRICE_MISMATCH}) 로 거절된다 — 가격 수정이 진행 중인 구매를 조용히 바꾸지 못한다.
     */
    @PatchMapping("/listings/{listingId}/price")
    ResponseEntity<ListingDetailResponseDto> updatePrice(
            @PathVariable Long listingId,
            @Valid @RequestBody UpdateListingPriceRequestDto request,
            @CurrentMember Long memberId);

    /**
     * 등록을 취소한다. 티켓은 다시 보유 상태로 돌아간다. 204 다.
     *
     * <p>{@code DELETE} 가 아닌 이유는 행을 지우지 않기 때문이다. 매물은 {@code CANCELED} 로 남고
     * {@code closedAt} 이 기록된다 — 취소 이력이 남아야 재양도 추적과 CS 가 가능하다.
     *
     * <p><b>페널티 규칙은 미확정이다</b> (D-7 100% / 하루 80% / 당일 10% 중 미정). 정해지면 여기서
     * 차감하게 되고 응답이 204 가 아니게 될 수 있다.
     */
    @PostMapping("/listings/{listingId}/cancel")
    ResponseEntity<Void> cancel(@PathVariable Long listingId,
                                @CurrentMember Long memberId);

    /**
     * 매물을 구매한다. 선착순이며 응모·추첨·가격제안은 없다. <b>200</b> 이다.
     *
     * <p>온체인 체결(코인 전송 + NFT 소유권 이전)까지 응답 전에 동기로 끝난다 - 200을 받았다는
     * 것 자체가 체결이 확정됐다는 뜻이다({@code PurchaseService} 참고). 실패하면 매물은 그대로
     * {@code LISTED}로 남으므로 다시 구매를 시도하면 된다.
     *
     * <p>{@code Idempotency-Key} 로 재시도가 결제를 두 번 일으키지 않게 한다. 클라이언트가 구매
     * 시도마다 UUID 를 만들고, 재시도는 <b>같은 키</b>로 보낸다.
     *
     * <p>이미 팔렸거나 취소됐으면 409, 가격이 다르면 409, 내 매물이면 409, 매물이 없으면 404,
     * 온체인 체결이 실패하면 409 다.
     */
    @PostMapping("/listings/{listingId}/purchase")
    ResponseEntity<PurchaseResponseDto> purchase(
            @PathVariable Long listingId,
            @RequestHeader("Idempotency-Key")
            @NotBlank(message = "멱등키는 필수입니다.")
            @Size(max = 100, message = "멱등키는 100자 이하여야 합니다.")
            String idempotencyKey,
            @Valid @RequestBody PurchaseRequestDto request,
            @CurrentMember Long memberId);
}
