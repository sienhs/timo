package com.ssafy.timo.domain.transfer.dto;

import java.time.LocalDateTime;

/**
 * 양도 마켓 운영 상태.
 *
 * <p>{@code opensAt}·{@code closesAt} 는 규칙(매일 20:00~23:59:59)이 아니라 <b>구체적인 일시</b>다.
 * 열려 있으면 지금 창, 닫혀 있으면 다음 창의 시각이라 앱은 "닫힘까지" 와 "오픈까지" 를 같은
 * 값으로 센다. {@code serverTime} 을 함께 주는 이유는 앱이 남은 시간을 자기 시계가 아니라
 * 서버 시계 기준으로 그리게 하기 위해서다 — 열림 판정 자체는 서버가 하므로 표시용이다.
 *
 * @param open       지금 열려 있는가
 * @param serverTime 판정에 쓴 서버 시각(초 단위)
 * @param opensAt    열려 있으면 이번 창이 열린 시각, 닫혀 있으면 다음에 여는 시각
 * @param closesAt   열려 있으면 이번 창이 닫히는 시각, 닫혀 있으면 다음 창이 닫히는 시각
 */
public record MarketHoursResponseDto(
        boolean open,
        LocalDateTime serverTime,
        LocalDateTime opensAt,
        LocalDateTime closesAt) {
}
