package com.ssafy.timo.domain.transfer.dto;

/**
 * 거래 상세에서 <b>요청자</b>가 그 거래의 어느 쪽인지. 같은 거래가 판매자에게는 {@link #SELLER},
 * 구매자에게는 {@link #BUYER} 로 내려간다. 저장하지 않고 응답 시점에 회원 id 를 비교해 정한다.
 *
 * <p>내 거래 내역의 {@link MyTradeType}(SALE/PURCHASE)과 이름을 달리 둔 이유는 그쪽이 "항목의 종류"
 * 이고 이쪽은 "내 입장" 이라서다. 상대가 누구인지는 어느 쪽에도 나오지 않는다.
 */
public enum TradeRole {

    /** 내가 판 거래. {@code ticket_trade.seller_member_id} 가 나다. */
    SELLER,

    /** 내가 산 거래. {@code ticket_trade.buyer_member_id} 가 나다. */
    BUYER
}
