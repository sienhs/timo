package com.ssafy.timo.domain.auth.dto;

/**
 * 중복 확인 결과.
 *
 * <p>이 응답은 <b>보증이 아니다.</b> 확인을 통과한 뒤 가입 요청이 도착하기까지 사이에 남이 같은 값을
 * 채갈 수 있다. 최종 판정은 가입 시 DB 유니크 제약이 하고 그때는 409 가 나간다.
 *
 * @param available 지금 시점에 쓸 수 있으면 true
 */
public record AvailabilityResponseDto(boolean available) {
}
