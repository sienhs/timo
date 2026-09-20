package com.ssafy.timo.domain.transfer.dto;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.entity.TradeStatus;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;

/**
 * 거래 한 건의 상세. 판매 완료 알림({@code LINK_TYPE TRADE})이 가리키는 화면이고, 구매 완료 화면의 상태
 * 확인도 내 거래 내역 전체를 긁는 대신 이걸 본다.
 *
 * <p>필드는 내 거래 내역 항목({@link MyTradeSummaryResponseDto})과 같은 이름을 쓴다. 앱이 같은 파서로
 * 읽을 수 있게 하려는 것이다. 다른 점은 {@code role}(내 입장)이 있고, {@code status} 가 매물 상태를 섞은
 * {@code MyTradeStatus} 가 아니라 온체인 진행을 뜻하는 {@link TradeStatus} 그대로라는 것뿐이다.
 *
 * <p><b>거래 상대는 드러나지 않는다.</b> {@code sellerMemberId}, {@code buyerMemberId}, {@code ticketId},
 * {@code tokenId} 는 싣지 않는다. {@code txHash} 도 온체인 연동 전이라 넣지 않는다.
 */
public record TradeDetailResponseDto(
        Long tradeId,
        Long listingId,
        TradeRole role,
        TradeStatus status,
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
        LocalDateTime tradedAt
) {

    public static TradeDetailResponseDto from(TicketTrade trade, TradeRole role, ImageStorage imageStorage) {
        TicketListing listing = trade.getListing();
        Concert concert = listing.getConcert();

        return new TradeDetailResponseDto(
                trade.getId(),
                listing.getId(),
                role,
                trade.getStatus(),
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
