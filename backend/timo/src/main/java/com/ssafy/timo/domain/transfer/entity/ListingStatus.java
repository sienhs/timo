package com.ssafy.timo.domain.transfer.entity;

/**
 * 양도 매물의 상태.
 *
 * <p>매물의 생명주기는 이 값이 정본이다. {@code ticket.status} 의 {@code LISTED} 는 파생 표시값이므로
 * 둘이 어긋나면 이쪽을 믿는다.
 *
 * <p>{@link #LISTED} 를 벗어나면 되돌아오지 않는다. 취소한 티켓을 다시 팔면 매물이 새로 생긴다.
 * 그래야 재양도 이력이 {@code ticket_listing} 에 그대로 쌓인다.
 */
public enum ListingStatus {

    /** 구매 가능. 매물 목록에 나오는 유일한 상태다. */
    LISTED,

    /** 체결됨. */
    SOLD,

    /** 판매자가 등록을 취소함. */
    CANCELED
}
