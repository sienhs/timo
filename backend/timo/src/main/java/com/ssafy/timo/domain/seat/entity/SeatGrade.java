package com.ssafy.timo.domain.seat.entity;

/**
 * 구역 등급. 같은 공연장 안에서도 무대와의 거리·시야에 따라 가격대가 갈리므로
 * 좌석이 아니라 구역({@link Section}) 단위로 매긴다.
 *
 * <p>실제 가격은 등급이 아니라 {@link Section#getPrice()} 가 들고 있다. 등급은 화면 표기와
 * 정렬 기준용이다.
 */
public enum SeatGrade {

    /** TODO : 좌석 등급이 생긴다면 변경 예정**/
    /** 일반석. 등급을 따로 나누지 않는 공연장의 기본값이다. */
    COMMON
}
