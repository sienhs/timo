package com.ssafy.timo.domain.transfer.dto;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;

/**
 * 내 거래 내역의 항목 하나. 판매와 구매가 같은 모양으로 섞여 있다.
 *
 * <p><b>거래 상대는 어느 쪽에서도 드러나지 않는다.</b> 판매 내역에 누가 샀는지, 구매 내역에
 * 누가 팔았는지 나오지 않는다. {@code ticketId} 와 {@code tokenId} 도 없다.
 *
 * <p>{@code tradeId} 는 {@link MyTradeType#PURCHASE} 에만 값이 있다. 판매는 아직 팔리지 않았을
 * 수 있어 체결 자체가 없다.
 *
 * <p>{@code occurredAt} 은 판매면 등록 시각, 구매면 체결 시각이다. 두 테이블을 한 목록으로
 * 합치려면 정렬 기준이 되는 시각의 이름이 하나여야 한다.
 *
 * <p>내가 등록한 매물이 팔리면 {@code SALE} 항목의 상태가 {@code SOLD} 로 바뀔 뿐,
 * 별도의 {@code PURCHASE} 항목이 생기지는 않는다.
 */
public record MyTradeSummaryResponseDto(
        MyTradeType type,
        Long tradeId,
        Long listingId,
        MyTradeStatus status,
        Long concertId,
        String concertTitle,
        String posterImageUrl,
        LocalDateTime startDate,
        String venueName,
        String sectionName,
        SeatGrade grade,
        int seatNo,
        int seatCol,
        long price,
        long faceValue,
        LocalDateTime occurredAt
) {

    /** 내가 올린 매물. 팔렸는지 여부는 매물의 상태가 말해 준다. */
    public static MyTradeSummaryResponseDto ofSale(TicketListing listing, ImageStorage imageStorage) {
        Concert concert = listing.getConcert();

        return new MyTradeSummaryResponseDto(
                MyTradeType.SALE,
                null,
                listing.getId(),
                MyTradeStatus.of(listing.getStatus()),
                concert.getId(),
                concert.getTitle(),
                imageStorage.getUrl(concert.getPosterImageKey()),
                concert.getStartDate(),
                concert.getVenue().getName(),
                listing.getSection().getName(),
                listing.getSection().getGrade(),
                listing.getSeatNo(),
                listing.getSeatCol(),
                listing.getPrice(),
                listing.getFaceValue(),
                listing.getListedAt());
    }

    /** 내가 사들인 건. 상태는 매물이 아니라 <b>온체인 전송</b>의 진행을 뜻한다. */
    public static MyTradeSummaryResponseDto ofPurchase(TicketTrade trade, ImageStorage imageStorage) {
        TicketListing listing = trade.getListing();
        Concert concert = listing.getConcert();

        return new MyTradeSummaryResponseDto(
                MyTradeType.PURCHASE,
                trade.getId(),
                listing.getId(),
                MyTradeStatus.of(trade.getStatus()),
                concert.getId(),
                concert.getTitle(),
                imageStorage.getUrl(concert.getPosterImageKey()),
                concert.getStartDate(),
                concert.getVenue().getName(),
                listing.getSection().getName(),
                listing.getSection().getGrade(),
                listing.getSeatNo(),
                listing.getSeatCol(),
                trade.getPrice(),
                listing.getFaceValue(),
                trade.getTradedAt());
    }
}
