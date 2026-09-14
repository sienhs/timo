package com.ssafy.timo.domain.transfer.dto;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.entity.TradeStatus;

import java.time.LocalDateTime;

/**
 * 양도 구매 체결 결과.
 *
 * <p>응답 시점의 {@code status} 는 언제나 {@link TradeStatus#PENDING} 이다. DB 상 체결만 끝났고
 * 코인 전송·NFT 소유권 이전은 DB 트랜잭션 밖이라 아직 남아 있다. 체결 API 가 200 이 아니라
 * 202 인 이유이며, 클라이언트는 {@code status} 가 {@code CONFIRMED} 로 바뀌는지 확인해야 한다.
 * 확인은 별도 폴링 API 가 아니라 내 거래 내역({@link MyTradeSummaryResponseDto})에서 같은
 * {@code tradeId} 를 찾아 읽는다.
 *
 * <p><b>{@code txHash} 를 담지 않는다.</b> 온체인 연동 전이라 항상 비어 있을 값이고, 넣어 두면
 * 앱이 있지도 않은 값을 기다린다. 연동할 때 다시 넣는다.
 *
 * <p>{@code tradeId} 는 {@code ticket_trade} 의 PK 다. 온체인 {@code Marketplace.buy} 가 받는
 * {@code tradeId}(bytes32) 와는 <b>다른 값이다.</b> 이름이 같아 헷갈리기 쉬운데, 온체인 쪽은
 * 연동 시 이 PK 에서 파생시키되 코드에서는 다른 이름으로 부른다.
 *
 * <p>좌석번호는 여기에도 없다. 체결 후 좌석 정보는 티켓 도메인에서 조회한다.
 */
public record PurchaseResponseDto(
        Long tradeId,
        Long listingId,
        TradeStatus status,
        int price,
        String concertTitle,
        LocalDateTime startDate,
        String venueName,
        String sectionName,
        LocalDateTime tradedAt
) {

    public static PurchaseResponseDto from(TicketTrade trade) {
        TicketListing listing = trade.getListing();
        Concert concert = listing.getConcert();

        return new PurchaseResponseDto(
                trade.getId(),
                listing.getId(),
                trade.getStatus(),
                trade.getPrice(),
                concert.getTitle(),
                concert.getStartDate(),
                concert.getVenue().getName(),
                listing.getSection().getName(),
                trade.getTradedAt());
    }
}
