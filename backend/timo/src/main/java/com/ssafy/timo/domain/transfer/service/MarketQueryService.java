package com.ssafy.timo.domain.transfer.service;

import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.transfer.dto.ListingDetailResponseDto;
import com.ssafy.timo.domain.transfer.dto.ListingSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MarketConcertRow;
import com.ssafy.timo.domain.transfer.dto.MarketConcertSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MarketListRequestDto;
import com.ssafy.timo.domain.transfer.dto.MyTradeRow;
import com.ssafy.timo.domain.transfer.dto.MyTradeStatus;
import com.ssafy.timo.domain.transfer.dto.MyTradeSummaryResponseDto;
import com.ssafy.timo.domain.transfer.dto.MyTradeType;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.exception.ListingNotFoundException;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PagedModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.LocalDateTime;

/**
 * 양도 마켓 조회.
 *
 * <p>쓰기({@link ListingService} · {@link PurchaseService})와 나눈 이유는 읽기 전용 트랜잭션으로
 * 묶기 위해서다. 조회가 쓰기와 같은 클래스에 있으면 실수로 쓰기 트랜잭션에서 돌기 쉽다.
 *
 * <p><b>응답에 담지 않는 값의 기준은 네 경로가 모두 같다.</b> 좌석번호 · 판매자 식별자 ·
 * {@code ticketId} · {@code tokenId} 는 상세라고 해서 예외를 두지 않는다. 그래서 조회가 {@code ticket}
 * 과 {@code seat} 를 아예 경유하지 않도록 매물이 공연·구역·정가를 직접 들고 있다.
 *
 * <p>{@code mine} 은 요청자 본인에게만 true 이므로 익명성과 무관하다. 목록에서 내 것을 빼면 내가
 * 올린 매물이 지금 어떤 가격대에 놓여 있는지 알 수 없어 함께 내려 준다.
 *
 * <p><b>남의 매물이 보이는 두 경로(공연 목록, 공연별 매물)는 운영 시간에만 연다.</b> 닫힌 시간에 등록된
 * 매물이 여기서 처음 드러나므로, 이 가드가 곧 "08:00 에 일괄로 올라간다" 의 구현이다. 상세와 내 내역은
 * 판매자가 자기 매물을 보는 경로라 시간을 보지 않는다 — 구매는 따로 막혀 있어 새는 것이 없다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class MarketQueryService {

    /** 공연 목록 · 매물 목록 · 내 내역 모두 순서가 하나뿐이라 호출하는 쪽이 정렬을 고르지 않는다. */
    private static final Sort LOWEST_PRICE_FIRST =
            Sort.by(Sort.Order.asc("price"), Sort.Order.asc("id"));

    private final ConcertRepository concertRepository;
    private final TicketListingRepository ticketListingRepository;
    private final TicketTradeRepository ticketTradeRepository;
    private final ImageStorage imageStorage;
    private final MarketHoursService marketHoursService;
    private final Clock clock;

    /**
     * 양도 매물이 올라와 있는 공연 목록. 임박한 공연부터다.
     *
     * <p>공연마다 매물 수와 최저가만 준다. 상위 묶음의 목록에 개별 매물을 실으면 응답이 매물 수에
     * 비례해 커진다.
     */
    public PagedModel<MarketConcertSummaryResponseDto> findConcerts(MarketListRequestDto request) {
        marketHoursService.requireOpen();

        // 정렬은 쿼리 안에 있다. 여기서 또 넘기면 order by 가 중복된다.
        return new PagedModel<>(ticketListingRepository
                .findConcertSummaries(LocalDateTime.now(clock), marketHoursService.visibleBefore(),
                        request.toPageable(Sort.unsorted()))
                .map(this::toConcertSummary));
    }

    /**
     * 공연 하나의 매물 목록. 낮은 가격순이다.
     *
     * <p>공연이 없으면 404 지만, <b>공연이 있고 매물만 없으면 빈 목록으로 200</b> 이다. 둘은 화면이
     * 다르게 안내해야 한다 — 전자는 잘못된 링크고 후자는 "아직 나온 매물이 없다" 다.
     */
    public PagedModel<ListingSummaryResponseDto> findListings(Long concertId,
                                                              MarketListRequestDto request,
                                                              Long requesterId) {
        marketHoursService.requireOpen();

        if (!concertRepository.existsById(concertId)) {
            throw new ConcertNotFoundException(concertId);
        }

        return new PagedModel<>(ticketListingRepository
                .findVisibleByConcertId(concertId, marketHoursService.visibleBefore(),
                        request.toPageable(LOWEST_PRICE_FIRST))
                .map(listing -> ListingSummaryResponseDto.from(listing, requesterId)));
    }

    /**
     * 매물 한 건의 상세.
     *
     * <p>팔렸거나 취소된 매물도 200 으로 조회된다. 구매 가능 여부는 {@code status} 로 판단한다.
     */
    public ListingDetailResponseDto findListing(Long listingId, Long requesterId) {
        TicketListing listing = ticketListingRepository.findDetailById(listingId)
                .orElseThrow(() -> new ListingNotFoundException(listingId));

        return ListingDetailResponseDto.from(listing, imageStorage, requesterId);
    }

    /**
     * 내 거래 내역. 판매와 구매를 한 목록에 섞어 최신순으로 준다.
     *
     * <p>두 테이블을 합치는 일은 DB 가 한다({@code TicketTradeRepository.findMyTrades}).
     */
    public PagedModel<MyTradeSummaryResponseDto> findMyTrades(MarketListRequestDto request, Long memberId) {
        return new PagedModel<>(ticketTradeRepository
                .findMyTrades(memberId, request.toPageable(Sort.unsorted()))
                .map(this::toMyTrade));
    }

    private MarketConcertSummaryResponseDto toConcertSummary(MarketConcertRow row) {
        return new MarketConcertSummaryResponseDto(
                row.getConcertId(),
                row.getTitle(),
                imageStorage.getUrl(row.getPosterImageKey()),
                row.getStartDate(),
                row.getEndDate(),
                row.getVenueName(),
                row.getListingCount(),
                row.getLowestPrice());
    }

    /**
     * 합쳐진 한 줄을 응답으로 옮긴다.
     *
     * <p>{@code status} 는 판매면 매물 상태, 구매면 온체인 전송 상태라 한 컬럼에 두 enum 이 섞여
     * 있다. 값이 겹치지 않게 만들어 둔 덕에 {@link MyTradeStatus} 하나로 받는다 — 클라이언트가
     * {@code type} 을 먼저 분기해야 상태를 파싱할 수 있는 상황을 피하려고 그렇게 정했다.
     */
    private MyTradeSummaryResponseDto toMyTrade(MyTradeRow row) {
        return new MyTradeSummaryResponseDto(
                MyTradeType.valueOf(row.getTradeType()),
                row.getTradeId(),
                row.getListingId(),
                MyTradeStatus.valueOf(row.getStatus()),
                row.getConcertId(),
                row.getConcertTitle(),
                imageStorage.getUrl(row.getPosterImageKey()),
                row.getStartDate(),
                row.getVenueName(),
                row.getSectionName(),
                SeatGrade.valueOf(row.getGrade()),
                row.getSeatNo(),
                row.getSeatCol(),
                row.getPrice(),
                row.getFaceValue(),
                row.getOccurredAt());
    }
}
