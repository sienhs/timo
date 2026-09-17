package com.ssafy.timo.domain.offer.entity;

/**
 * 취소표 구매 기회의 상태.
 *
 * <p>"열려 있다" 의 판정은 {@link #OFFERED} 만으로 끝나지 않는다. 기한이 지나도 행은 {@code OFFERED}
 * 로 남아 있을 수 있어(스케줄러 없음) 조회는 언제나 {@code expires_at > now} 를 함께 본다.
 * {@link #EXPIRED} 는 같은 좌석에 다음 기회를 열어야 할 때 유니크 제약을 비우려고 뒤늦게 적는 값이다.
 */
public enum OfferStatus {

    OFFERED,

    ACCEPTED,

    EXPIRED
}
