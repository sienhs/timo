package com.ssafy.timo.domain.transfer.dto;

/**
 * 내 거래 내역 항목이 판매인지 구매인지.
 *
 * <p>판매와 구매를 한 목록에 섞어 주기 때문에 필요하다. 경로를 둘로 나누면 "내 거래 내역"
 * 화면 하나가 두 번 호출하고 시간순 병합을 클라이언트가 해야 한다.
 */
public enum MyTradeType {

    /** 내가 양도 매물로 올린 건. {@code ticket_listing.seller_member_id} 기준이다. */
    SALE,

    /** 내가 사들인 건. {@code ticket_trade.buyer_member_id} 기준이다. */
    PURCHASE
}
