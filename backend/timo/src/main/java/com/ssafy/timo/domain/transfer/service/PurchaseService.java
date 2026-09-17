package com.ssafy.timo.domain.transfer.service;

import com.ssafy.timo.domain.transfer.dto.PurchaseRequestDto;
import com.ssafy.timo.domain.transfer.dto.PurchaseResponseDto;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.exception.CannotBuyOwnListingException;
import com.ssafy.timo.domain.transfer.exception.ListingAlreadyClosedException;
import com.ssafy.timo.domain.transfer.exception.ListingNotFoundException;
import com.ssafy.timo.domain.transfer.exception.ListingPriceMismatchException;
import com.ssafy.timo.domain.transfer.exception.TradePriceExceedsFaceValueException;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;

/**
 * 양도 매물 체결.
 *
 * <p>선착순이며 응모·추첨·가격제안은 없다.
 *
 * <h2>아직 하지 않는 것</h2>
 *
 * <p><b>코인 전송과 NFT 소유권 이전이 없다.</b> 둘 다 온체인이고 연동 방식이 정해지지 않았다
 * ({@code TicketTransferService} 는 인터페이스만 있고 구현체가 없다). 그래서 체결은 DB 상태만 바꾸고
 * 끝나며, 모든 거래가 {@code PENDING} 에 머문다. 체결 API 가 200 이 아니라 <b>202</b> 인 이유다.
 *
 * <p>결과적으로 <b>잔액을 확인하지 않는다.</b> 코인이 움직이지 않으므로 잔액 부족 거절도 없다.
 * 온체인이 붙으면 {@code TicketVault} 가 막는다.
 *
 * <p><b>멱등키를 저장하지 않는다.</b> 규약은 {@code Idempotency-Key} 헤더를 필수로 받지만, 저장 대상인
 * {@code balance_transaction} 은 지갑 도메인이고 Redis 도 아직 쓰지 않는다. 지금은 형식만 검증하고
 * 버린다 — <b>같은 키로 재시도하면 멱등이 아니라 409 가 나간다.</b> 재시도가 결제를 두 번 일으키지는
 * 않지만(매물이 이미 {@code SOLD}), 앱이 기대하는 "같은 응답" 은 아니다. 연동 시 함께 채운다.
 */
@Service
@RequiredArgsConstructor
public class PurchaseService {

    private final TicketListingRepository ticketListingRepository;
    private final TicketTradeRepository ticketTradeRepository;
    private final MarketHoursService marketHoursService;
    private final Clock clock;

    /**
     * 매물을 산다.
     *
     * <p>처리 순서가 규약의 핵심이다.
     *
     * <ol>
     *   <li>운영 시간인가 → 409. 닫힌 마켓에서 자리를 먼저 잡는 일이 없도록 UPDATE 앞에 둔다</li>
     *   <li>매물이 있는가 → 404</li>
     *   <li>{@code LISTED} 인 행만 {@code SOLD} 로 조건부 UPDATE. 영향 행 0 이면 → 409</li>
     *   <li>{@code expectedPrice} 가 등록가와 같은가 → 409</li>
     *   <li>내 매물이 아닌가 → 409</li>
     *   <li>등록가가 정가 이하인가(재검증) → 422</li>
     *   <li>체결 기록 INSERT. 상태는 {@code PENDING}</li>
     * </ol>
     *
     * <p><b>3번이 동시 구매 방어의 전부다.</b> 조회해서 {@code LISTED} 인지 확인한 뒤 UPDATE 하면 두
     * 요청이 같은 매물을 통과한다. 확인과 전이가 한 문장 안에서 일어나야 선착순이 성립한다.
     *
     * <p>그래서 검증이 전이보다 <b>뒤에</b> 온다. 순서가 거꾸로 보이지만 안전하다 — 4~6 번에서
     * 예외가 나면 트랜잭션이 통째로 되돌아가 {@code SOLD} 도 함께 풀린다. 먼저 자리를 잡고 나서
     * 따지는 쪽이, 따지는 동안 남에게 자리를 빼앗기는 것보다 낫다.
     *
     * <p>2 번을 따로 두는 이유는 <b>404 와 409 를 구분하기 위해서다.</b> 없는 매물도 조건부 UPDATE 의
     * 영향 행은 0 이라, 존재 확인을 건너뛰면 "없는 매물" 이 "이미 팔린 매물" 로 보인다. 앱은 둘을
     * 다르게 안내해야 한다.
     */
    @Transactional
    public PurchaseResponseDto purchase(Long listingId, PurchaseRequestDto request, Long buyerId) {
        marketHoursService.requireOpen();

        LocalDateTime now = LocalDateTime.now(clock);

        if (!ticketListingRepository.existsById(listingId)) {
            throw new ListingNotFoundException(listingId);
        }
        if (ticketListingRepository.markSoldIfListed(listingId, now) == 0) {
            throw new ListingAlreadyClosedException(listingId);
        }

        // 조건부 UPDATE 가 영속성 컨텍스트를 비우므로 여기서 다시 읽는다. 응답이 공연·공연장·구역을
        // 쓰므로 상세용 조회로 함께 읽어 둔다.
        TicketListing listing = ticketListingRepository.findDetailById(listingId)
                .orElseThrow(() -> new ListingNotFoundException(listingId));

        if (listing.getPrice() != request.expectedPrice()) {
            // 사용자가 본 금액과 다른 금액이 빠져나가면 안 된다. 실제 가격은 메시지에 담지 않는다 —
            // 남의 매물 가격을 확인하는 경로가 되면 안 된다.
            throw new ListingPriceMismatchException(listingId);
        }
        if (listing.isSeller(buyerId)) {
            throw new CannotBuyOwnListingException(listingId);
        }
        if (listing.getPrice() > listing.getFaceValue()) {
            // 등록 때도 본 검사다. face_value 는 등록 시점 스냅샷이라 불변이므로 정상 경로에서는
            // 도달하지 않는다. 데이터가 손상됐을 때만 걸리는 방어선이고, 그래도 두는 것은 정가 초과
            // 판매 차단이 이 서비스의 존재 이유이기 때문이다.
            throw new TradePriceExceedsFaceValueException(listingId);
        }

        TicketTrade trade = ticketTradeRepository.save(TicketTrade.record(listing, buyerId, now));

        return PurchaseResponseDto.from(trade);
    }
}
