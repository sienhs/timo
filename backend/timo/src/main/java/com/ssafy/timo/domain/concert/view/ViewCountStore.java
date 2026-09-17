package com.ssafy.timo.domain.concert.view;

/**
 * 공연 조회수의 실시간 증가분을 보관한다.
 *
 * <p>DB에 저장된 조회수는 기준값으로만 사용한다. 구현체는 애플리케이션 메모리나 Redis처럼
 * 빠르게 증가 연산을 처리할 수 있는 저장소가 될 수 있다.
 */
public interface ViewCountStore {

    /**
     * 기준 조회수에서 하나 증가한 현재 조회수를 반환한다.
     *
     * @param concertId 공연 식별자
     * @param persistedViewCount DB에 저장된 기준 조회수
     */
    int incrementAndGet(long concertId, int persistedViewCount);
}
