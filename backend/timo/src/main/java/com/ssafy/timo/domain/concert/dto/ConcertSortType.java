package com.ssafy.timo.domain.concert.dto;

import org.springframework.data.domain.Sort;

/**
 * 공연 목록 정렬 기준.
 *
 * <p>정렬을 엔티티 필드명이 아니라 enum 으로 받는 이유는 두 가지다. 클라이언트가 임의의 필드명을
 * 보내면(예: {@code sort=venue.address}) 매핑되지 않는 속성일 때 500 이 나고, 매핑되는 속성이면
 * 내부 모델 구조가 그대로 API 규약이 되어 버린다. 허용할 정렬만 여기에 열거해 둔다.
 */
public enum ConcertSortType {

    /** 최근 등록순. 목록의 기본값이다. */
    LATEST(Sort.by(Sort.Order.desc("createdAt"))),

    /** 조회수 많은 순. 홈의 "인기 공연"에 쓴다. */
    POPULAR(Sort.by(Sort.Order.desc("viewCount"))),

    /**
     * 예매 오픈이 이른 순. 홈의 "오픈 임박"에 쓴다.
     *
     * <p>오픈 일시는 선택값이라 비어 있을 수 있다. 미정인 공연이 목록 맨 앞을 차지하면
     * "임박"이라는 말과 어긋나므로 뒤로 보낸다. 이미 오픈한 공연을 걸러내지는 않는다 —
     * 그건 정렬이 아니라 필터의 몫이다.
     */
    OPEN_SOON(Sort.by(Sort.Order.asc("openAt").nullsLast())),

    /** 공연 시작이 이른 순. 오픈 일시와 같은 이유로 미정인 공연은 뒤로 보낸다. */
    START_DATE(Sort.by(Sort.Order.asc("startDate").nullsLast()));

    private final Sort sort;

    ConcertSortType(Sort sort) {
        this.sort = sort;
    }

    /**
     * 정렬 조건을 돌려준다. 어느 기준이든 마지막에 {@code id} 내림차순이 붙는다.
     *
     * <p>정렬 키 값이 같은 행들 사이의 순서가 매 쿼리마다 달라지면 페이지 경계에서 같은 공연이
     * 두 번 나오거나 아예 빠질 수 있다. 유일한 값을 마지막 정렬 키로 두어 순서를 고정한다.
     *
     * <p>동점 처리용 정렬은 상수 필드로 두지 않는다. enum 상수는 static 필드보다 먼저
     * 초기화되므로 생성자에서 참조하면 {@code null} 이다.
     */
    public Sort toSort() {
        return sort.and(Sort.by(Sort.Order.desc("id")));
    }
}
