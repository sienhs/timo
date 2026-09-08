package com.ssafy.timo.domain.seat.repository;

/**
 * 구역 하나의 예매 가능 좌석 수.
 *
 * <p>구역마다 {@code count} 를 따로 날리면 구역 수만큼 쿼리가 나가므로, 한 번의 group by 결과를
 * 이 모양으로 받는다.
 *
 * <p>좌석이 하나도 남지 않은 구역은 group by 결과에 아예 나오지 않는다. 읽는 쪽에서 0 으로 채운다.
 */
public record SectionAvailableCount(Long sectionId, long availableCount) {
}
