package com.ssafy.timo.global.config.transfer;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalTime;
import java.util.Map;
import org.springframework.boot.context.properties.bind.Binder;
import org.springframework.boot.context.properties.source.MapConfigurationPropertySource;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/** 잘못된 운영 시간은 첫 요청이 아니라 기동 시점에 걸려야 한다. */
class MarketHoursPropertiesTest {

    @Test
    void bindingDefaultsToDelayAndSupportsExplicitDisable() {
        var source = new MapConfigurationPropertySource(Map.of(
                "market.hours.open-at", "08:00:00",
                "market.hours.close-at", "23:00:00"));
        assertThat(new Binder(source).bind("market.hours", MarketHoursProperties.class)
                .get().listingDelayEnabled()).isTrue();
        source.put("market.hours.listing-delay-enabled", "false");
        assertThat(new Binder(source).bind("market.hours", MarketHoursProperties.class)
                .get().listingDelayEnabled()).isFalse();
    }

    @Test
    @DisplayName("20:00:00~23:59:59 는 유효하다")
    void acceptsDecidedWindow() {
        assertThatCode(() -> new MarketHoursProperties(LocalTime.of(20, 0, 0), LocalTime.of(23, 59, 59)))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("닫는 시각이 여는 시각보다 앞이면 기동 실패 - 자정을 넘기는 창은 받지 않는다")
    void rejectsWindowCrossingMidnight() {
        assertThatThrownBy(() -> new MarketHoursProperties(LocalTime.of(22, 0), LocalTime.of(2, 0)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("close-at");
    }

    @Test
    @DisplayName("여는 시각과 닫는 시각이 같아도 기동 실패 - 1초도 열리지 않는 창이다")
    void rejectsEmptyWindow() {
        assertThatThrownBy(() -> new MarketHoursProperties(LocalTime.of(20, 0), LocalTime.of(20, 0)))
                .isInstanceOf(IllegalStateException.class);
    }

    @Test
    @DisplayName("둘 중 하나라도 없으면 기동 실패")
    void rejectsMissingValue() {
        assertThatThrownBy(() -> new MarketHoursProperties(null, LocalTime.of(23, 59, 59)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("필수");
        assertThatThrownBy(() -> new MarketHoursProperties(LocalTime.of(20, 0), null))
                .isInstanceOf(IllegalStateException.class);
    }
}
