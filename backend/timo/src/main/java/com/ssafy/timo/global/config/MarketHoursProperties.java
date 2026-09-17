package com.ssafy.timo.global.config;

import java.time.LocalTime;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 양도 마켓 운영 시간. 매일 {@code openAt} 부터 {@code closeAt} 까지(양 끝 포함) 열린다.
 *
 * <p>규칙은 환경과 무관해야 하므로 {@code application.yml} 한 곳에만 둔다. 앱은 이 값을 서버에서
 * 받아 표시만 하고, 열림 판정은 서버 {@code Clock} 이 한다 — 기기 시계를 돌려도 뚫리지 않는다.
 *
 * <p>자정을 넘기는 창(예: 22:00~02:00)은 받지 않는다. 확정된 규칙(20:00:00~23:59:59)에 필요 없고,
 * 허용하면 "어제 창이 아직 열려 있는가" 를 매 판정마다 함께 봐야 해서 경계가 두 배로 는다.
 *
 * @param openAt  여는 시각(포함)
 * @param closeAt 닫는 시각(포함). {@code openAt} 보다 뒤여야 한다
 */
@ConfigurationProperties(prefix = "market.hours")
public record MarketHoursProperties(LocalTime openAt, LocalTime closeAt) {

    public MarketHoursProperties {
        if (openAt == null || closeAt == null) {
            throw new IllegalStateException("market.hours.open-at 과 close-at 은 필수입니다.");
        }
        if (!closeAt.isAfter(openAt)) {
            // 기동 시점에 터뜨린다. 20:00 에 첫 등록 요청이 409 로 떨어지고 나서 알면 늦다.
            throw new IllegalStateException(
                    "market.hours.close-at(%s) 은 open-at(%s) 보다 뒤여야 합니다.".formatted(closeAt, openAt));
        }
    }
}
