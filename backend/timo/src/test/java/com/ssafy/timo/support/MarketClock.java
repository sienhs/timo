package com.ssafy.timo.support;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;

/**
 * 양도 마켓 운영 시간 판정에만 쓰는 조작 가능한 시계.
 *
 * <p>통합 테스트는 공용 {@code Clock} 빈을 갈아 끼울 수 없다({@link IntegrationTest} 규약). 그래서
 * {@code MarketHoursService} 하나만 이 시계로 조립해 두고({@link MarketHoursTestConfig}), 테스트가
 * {@link #open()} 과 {@link #closed()} 로 창 안팎을 오간다. 날짜는 실제 오늘이라 다른 시계와 어긋나지 않는다.
 *
 * <p>컨텍스트가 공유되므로 닫은 테스트는 끝나기 전에 {@link #open()} 으로 되돌려야 한다.
 */
public final class MarketClock extends Clock {

    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
    private static final LocalTime INSIDE_WINDOW = LocalTime.of(21, 0);
    private static final LocalTime OUTSIDE_WINDOW = LocalTime.of(12, 0);

    private volatile Instant now;

    public MarketClock() {
        open();
    }

    /** 오늘 21:00 — 기본값. 대부분의 테스트는 열린 마켓을 전제한다. */
    public void open() {
        at(INSIDE_WINDOW);
    }

    /** 오늘 12:00. */
    public void closed() {
        at(OUTSIDE_WINDOW);
    }

    public void at(LocalTime time) {
        this.now = LocalDateTime.of(LocalDate.now(ZONE), time).atZone(ZONE).toInstant();
    }

    @Override
    public ZoneId getZone() {
        return ZONE;
    }

    @Override
    public Clock withZone(ZoneId zone) {
        return this;
    }

    @Override
    public Instant instant() {
        return now;
    }
}
