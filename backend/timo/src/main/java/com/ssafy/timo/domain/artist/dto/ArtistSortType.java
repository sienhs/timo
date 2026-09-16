package com.ssafy.timo.domain.artist.dto;

import org.springframework.data.domain.Sort;

/**
 * 아티스트 목록 정렬 기준.
 *
 * <p>정렬을 엔티티 필드명이 아니라 enum 으로 받는 이유는
 * {@link com.ssafy.timo.domain.concert.dto.ConcertSortType} 과 같다. 클라이언트가 임의의 필드명을
 * 보내면 매핑되지 않는 속성일 때 500 이 나고, 매핑되면 내부 모델 구조가 그대로 API 규약이 된다.
 */
public enum ArtistSortType {

    /**
     * 이름 오름차순. 목록의 기본값이다.
     *
     * <p>아티스트 목록은 공연처럼 "새로 올라온 것"을 보는 화면이 아니라 이름으로 찾아가는 화면이라
     * 등록순이 아니라 이름순이 기본이다.
     *
     * <p>{@code artist_name} 은 not null 이 아니라 비어 있을 수 있다. 이름 없는 행이 목록 맨 앞을
     * 차지하면 가나다순이라는 말과 어긋나므로 뒤로 보낸다.
     */
    NAME(Sort.by(Sort.Order.asc("name").nullsLast())),

    /** 최근 등록순. */
    LATEST(Sort.by(Sort.Order.desc("createdAt")));

    private final Sort sort;

    ArtistSortType(Sort sort) {
        this.sort = sort;
    }

    /**
     * 정렬 조건을 돌려준다. 어느 기준이든 마지막에 {@code id} 내림차순이 붙는다.
     *
     * <p>동명이인이 있을 수 있어 이름만으로는 순서가 고정되지 않는다. 정렬 키 값이 같은 행들의 순서가
     * 매 쿼리마다 달라지면 페이지 경계에서 같은 아티스트가 두 번 나오거나 아예 빠진다.
     *
     * <p>동점 처리용 정렬은 상수 필드로 두지 않는다. enum 상수는 static 필드보다 먼저 초기화되므로
     * 생성자에서 참조하면 {@code null} 이다.
     */
    public Sort toSort() {
        return sort.and(Sort.by(Sort.Order.desc("id")));
    }
}
