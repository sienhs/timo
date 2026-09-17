package com.ssafy.timo.domain.transfer.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ssafy.timo.domain.transfer.dto.MarketHoursResponseDto;
import com.ssafy.timo.domain.transfer.exception.MarketClosedException;
import com.ssafy.timo.domain.transfer.exception.MarketOpenException;
import com.ssafy.timo.domain.transfer.exception.TransferErrorCode;
import com.ssafy.timo.global.config.MarketHoursProperties;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 운영 시간 창의 경계를 고정 시계로 본다.
 *
 * <p>통합 테스트는 {@code Clock} 빈을 갈아 끼울 수 없어(IntegrationTest 규약) test 프로파일을 종일
 * 열어 두므로, 20:00:00 과 23:59:59 양 끝이 정말 포함되는지는 여기서만 확인된다.
 */
class MarketHoursServiceTest {

    private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
    private static final MarketHoursProperties DAILY_20_TO_24 =
            new MarketHoursProperties(LocalTime.of(20, 0, 0), LocalTime.of(23, 59, 59));

    @Test
    @DisplayName("여는 시각 정각은 열려 있다 - 20:00:00 은 포함이다")
    void openAtOpeningSecond() {
        MarketHoursResponseDto status = at(LocalDateTime.of(2026, 9, 17, 20, 0, 0)).status();

        assertThat(status.open()).isTrue();
        assertThat(status.opensAt()).isEqualTo(LocalDateTime.of(2026, 9, 17, 20, 0, 0));
        assertThat(status.closesAt()).isEqualTo(LocalDateTime.of(2026, 9, 17, 23, 59, 59));
    }

    @Test
    @DisplayName("여는 시각 1초 전은 닫혀 있고 다음 창은 오늘이다")
    void closedOneSecondBeforeOpening() {
        MarketHoursResponseDto status = at(LocalDateTime.of(2026, 9, 17, 19, 59, 59)).status();

        assertThat(status.open()).isFalse();
        assertThat(status.opensAt()).isEqualTo(LocalDateTime.of(2026, 9, 17, 20, 0, 0));
        assertThat(status.closesAt()).isEqualTo(LocalDateTime.of(2026, 9, 17, 23, 59, 59));
    }

    @Test
    @DisplayName("닫는 시각 23:59:59 는 포함이고, 그 초의 소수점 이하도 열려 있다")
    void openThroughClosingSecond() {
        assertThat(at(LocalDateTime.of(2026, 9, 17, 23, 59, 59)).status().open()).isTrue();
        // 초 단위로 자르지 않으면 규칙에 적힌 마지막 1초가 사실상 사라진다.
        assertThat(at(LocalDateTime.of(2026, 9, 17, 23, 59, 59, 900_000_000)).status().open()).isTrue();
    }

    @Test
    @DisplayName("자정을 넘기면 닫히고 다음 창은 그날 20:00 이다")
    void closedAfterMidnightPointsToTonight() {
        MarketHoursResponseDto status = at(LocalDateTime.of(2026, 9, 18, 0, 0, 0)).status();

        assertThat(status.open()).isFalse();
        assertThat(status.opensAt()).isEqualTo(LocalDateTime.of(2026, 9, 18, 20, 0, 0));
        assertThat(status.closesAt()).isEqualTo(LocalDateTime.of(2026, 9, 18, 23, 59, 59));
    }

    @Test
    @DisplayName("서버 시각은 초 단위로 잘라 내려준다")
    void serverTimeIsTruncatedToSeconds() {
        MarketHoursResponseDto status = at(LocalDateTime.of(2026, 9, 17, 21, 30, 15, 123_456_789)).status();

        assertThat(status.serverTime()).isEqualTo(LocalDateTime.of(2026, 9, 17, 21, 30, 15));
    }

    @Test
    @DisplayName("닫혀 있으면 MARKET_CLOSED 로 거절하고 다음 여는 시각을 메시지에 싣는다")
    void requireOpenRejectsWhenClosed() {
        assertThatThrownBy(() -> at(LocalDateTime.of(2026, 9, 17, 12, 0, 0)).requireOpen())
                .isInstanceOf(MarketClosedException.class)
                .hasMessageContaining("2026-09-17T20:00")
                .extracting("errorCode").isEqualTo(TransferErrorCode.MARKET_CLOSED);
    }

    @Test
    @DisplayName("열려 있으면 통과한다")
    void requireOpenPassesWhenOpen() {
        assertThatCode(() -> at(LocalDateTime.of(2026, 9, 17, 22, 0, 0)).requireOpen())
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("열려 있으면 MARKET_OPEN 으로 거절하고 마감 시각을 메시지에 싣는다 - 가격 수정이 쓴다")
    void requireClosedRejectsWhenOpen() {
        assertThatThrownBy(() -> at(LocalDateTime.of(2026, 9, 17, 22, 0, 0)).requireClosed())
                .isInstanceOf(MarketOpenException.class)
                .hasMessageContaining("2026-09-17T23:59:59")
                .extracting("errorCode").isEqualTo(TransferErrorCode.MARKET_OPEN);
    }

    @Test
    @DisplayName("닫혀 있으면 requireClosed 는 통과한다")
    void requireClosedPassesWhenClosed() {
        assertThatCode(() -> at(LocalDateTime.of(2026, 9, 17, 12, 0, 0)).requireClosed())
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("노출 기준은 오늘 00:00 - 그보다 먼저 등록된 매물만 보인다")
    void visibleBeforeIsStartOfToday() {
        assertThat(at(LocalDateTime.of(2026, 9, 17, 21, 0, 0)).visibleBefore())
                .isEqualTo(LocalDateTime.of(2026, 9, 17, 0, 0, 0));
    }

    @Test
    @DisplayName("등록 다음 날 여는 시각에 처음 보인다 - 열린 시간에 등록해도 그날은 아니다")
    void visibleFromIsNextDayOpening() {
        MarketHoursService service = at(LocalDateTime.of(2026, 9, 17, 21, 0, 0));

        assertThat(service.visibleFrom(LocalDateTime.of(2026, 9, 17, 10, 0)))
                .isEqualTo(LocalDateTime.of(2026, 9, 18, 20, 0, 0));
        assertThat(service.visibleFrom(LocalDateTime.of(2026, 9, 17, 21, 30)))
                .isEqualTo(LocalDateTime.of(2026, 9, 18, 20, 0, 0));
    }

    @Test
    @DisplayName("종일 창(00:00:00~23:59:59)은 언제나 열려 있다")
    void allDayWindowIsAlwaysOpen() {
        MarketHoursProperties allDay = new MarketHoursProperties(LocalTime.MIDNIGHT, LocalTime.of(23, 59, 59));

        assertThat(at(allDay, LocalDateTime.of(2026, 9, 17, 0, 0, 0)).status().open()).isTrue();
        assertThat(at(allDay, LocalDateTime.of(2026, 9, 17, 23, 59, 59)).status().open()).isTrue();
    }

    private static MarketHoursService at(LocalDateTime now) {
        return at(DAILY_20_TO_24, now);
    }

    private static MarketHoursService at(MarketHoursProperties properties, LocalDateTime now) {
        return new MarketHoursService(properties, Clock.fixed(now.atZone(ZONE).toInstant(), ZONE));
    }
}
