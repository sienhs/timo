package com.ssafy.timo.domain.notification.entity;

/**
 * 알림을 눌렀을 때 앱이 어느 화면으로 가는지. 앱과 이 문자열을 맞춰야 하므로 이름을 함부로 바꾸지 않는다.
 *
 * <p>{@code linkId} 가 무엇을 가리키는지도 여기서 갈린다. 서버는 대상이 아직 있는지 확인하지 않는다.
 * 지워진 대상이면 앱이 이동에 실패했을 때 링크를 죽이고 문구만 보여 준다.
 */
public enum LinkType {

    /** 공연 상세. {@code linkId} 는 concert_id. */
    CONCERT,

    /** 양도 마켓 목록. 가리키는 대상이 없어 {@code linkId} 는 null. */
    MARKET,

    /** 거래 내역 상세. {@code linkId} 는 trade_id. */
    TRADE
}
