package com.ssafy.timo.domain.transfer.dto;

import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.transfer.entity.TicketListing;

import java.time.LocalDateTime;

/**
 * 매물 목록의 항목 하나.
 *
 * <p><b>좌석번호를 함께 공개한다</b>(2026-09-16 변경). 공식 마켓에서의 양도를 권장하는 플랫폼이라
 * 구매자가 목록에서 자리를 보고 고를 수 있어야 한다. 값은 매물이 등록 시점에 복사해 둔 것이라
 * 조회가 여전히 {@code seat} 테이블을 거치지 않는다.
 *
 * <p><b>판매자를 가리키는 값도 담지 않는다.</b> 회원 식별자는 물론 지갑 주소도 마찬가지다.
 * 지갑 주소는 온체인에 공개돼 있어 그 주소의 매물·거래가 전부 묶인다.
 *
 * <p>{@code ticketId} · {@code tokenId} 도 담지 않는다. 노출되면 원 예매 건과 재양도 이력이
 * 역추적된다. 외부로 나가는 식별자는 {@code listingId} 하나뿐이다.
 *
 * <p>{@code mine} 이 true 면 내가 올린 매물이다. 화면은 구매 버튼 대신 등록 취소 버튼을 보여 준다.
 * 본인에게만 true 라 익명성과는 무관하다. 목록에서 내 것을 빼면 내가 올린 매물이 지금 어떤
 * 가격대에 놓여 있는지 알 수 없어 함께 내려 준다.
 *
 * <p>공연 정보(제목·포스터·일시·공연장)는 상세({@link ListingDetailResponseDto})에만 있다.
 * 목록은 이미 공연 하나를 고른 뒤의 화면이라 매번 같은 값을 반복해 실어 보낼 이유가 없다.
 */
public record ListingSummaryResponseDto(
        Long listingId,
        String sectionName,
        SeatGrade grade,
        int seatNo,
        int seatCol,
        long price,
        long faceValue,
        int discountRate,
        boolean mine,
        LocalDateTime listedAt
) {

    public static ListingSummaryResponseDto from(TicketListing listing, Long requesterId) {
        return new ListingSummaryResponseDto(
                listing.getId(),
                listing.getSection().getName(),
                listing.getSection().getGrade(),
                listing.getSeatNo(),
                listing.getSeatCol(),
                listing.getPrice(),
                listing.getFaceValue(),
                listing.discountRate(),
                listing.isSeller(requesterId),
                listing.getListedAt());
    }
}
