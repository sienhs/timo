package com.ssafy.timo.domain.transfer.dto;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.global.storage.ImageStorage;

import java.time.LocalDateTime;

/**
 * 매물 한 건의 상세. 등록 응답도 같은 모양이다.
 *
 * <p>목록({@link ListingSummaryResponseDto})에 공연 정보와 {@code status} · {@code closedAt} 이
 * 더해진 것이다. 담지 않는 값의 기준은 목록과 똑같다 — <b>좌석번호 · 판매자 식별자 ·
 * {@code ticketId} · {@code tokenId} 는 상세라고 해서 예외를 두지 않는다.</b>
 *
 * <p>{@code status} 가 {@link ListingStatus#LISTED} 가 아닌 매물도 이 응답으로 조회된다.
 * 목록에서 상세로 들어가는 사이에 팔릴 수 있고, 그때 404 를 주면 화면이 "없는 매물"로 오해한다.
 * 구매 가능 여부는 이 값으로 판단한다.
 *
 * <p>등록 직후의 응답이면 {@code status} 는 항상 {@code LISTED}, {@code closedAt} 은 항상 비어 있다.
 */
public record ListingDetailResponseDto(
        Long listingId,
        ListingStatus status,
        Long concertId,
        String concertTitle,
        String posterImageUrl,
        LocalDateTime startDate,
        String venueName,
        String sectionName,
        SeatGrade grade,
        int price,
        int faceValue,
        int discountRate,
        boolean mine,
        LocalDateTime listedAt,
        LocalDateTime closedAt
) {

    public static ListingDetailResponseDto from(TicketListing listing,
                                                ImageStorage imageStorage,
                                                Long requesterId) {
        Concert concert = listing.getConcert();

        return new ListingDetailResponseDto(
                listing.getId(),
                listing.getStatus(),
                concert.getId(),
                concert.getTitle(),
                imageStorage.getUrl(concert.getPosterImageKey()),
                concert.getStartDate(),
                concert.getVenue().getName(),
                listing.getSection().getName(),
                listing.getSection().getGrade(),
                listing.getPrice(),
                listing.getFaceValue(),
                listing.discountRate(),
                listing.isSeller(requesterId),
                listing.getListedAt(),
                listing.getClosedAt());
    }
}
