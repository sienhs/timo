package com.ssafy.timo.domain.transfer.dto;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.entity.TradeStatus;

import java.time.LocalDateTime;

/**
 * 양도 구매 체결 결과.
 *
 * <p>응답 시점의 {@code status} 는 언제나 {@link TradeStatus#CONFIRMED} 다. 온체인 체결을 응답
 * 전에 동기로 끝내므로({@code PurchaseService}), 200을 받았다는 것 자체가 코인 전송과 NFT
 * 소유권 이전까지 끝났다는 뜻이다.
 *
 * <p><b>{@code txHash} 를 담지 않는다.</b> {@code TicketTrade}가 아직 그 값을 저장하지 않는다 -
 * 필요해지면 컬럼을 추가하고 함께 넣는다.
 *
 * <p>{@code tradeId} 는 {@code ticket_trade} 의 PK 다. 온체인 {@code Marketplace.buy} 가 받는
 * {@code tradeId}(bytes32) 와는 <b>다른 값이다.</b> 이름이 같아 헷갈리기 쉬운데, 온체인 쪽은
 * 연동 시 이 PK 에서 파생시키되 코드에서는 다른 이름으로 부른다.
 *
 * <p>좌석번호를 함께 준다. 체결 직후 화면이 "어느 자리를 샀는지" 를 바로 보여 줄 수 있어야 한다.
 */
public record PurchaseResponseDto(
        Long tradeId,
        Long listingId,
        TradeStatus status,
        long price,
        String concertTitle,
        LocalDateTime startDate,
        String venueName,
        String sectionName,
        int seatNo,
        int seatCol,
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
                listing.getSeatNo(),
                listing.getSeatCol(),
                trade.getTradedAt());
    }
}
