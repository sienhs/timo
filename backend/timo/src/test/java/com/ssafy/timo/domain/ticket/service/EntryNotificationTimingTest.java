package com.ssafy.timo.domain.ticket.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.notification.scheduler.EntryOpenSweep;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 입장 알림이 나가는 시각과 입장 QR 이 열리는 시각이 같은지 지킨다.
 *
 * <p>이 테스트가 이 패키지에 있는 이유는 QR 이 열리는 시간의 원본이 이 패키지 안에서만 보이기 때문이다.
 * 둘이 갈라지면 "입장할 수 있어요" 알림을 받고도 QR 이 안 나오거나, QR 이 나오는데 알림이 늦는다.
 */
class EntryNotificationTimingTest {

    @Test
    @DisplayName("입장 알림 시각은 입장 QR 이 열리는 시각과 같다")
    void entryNotification_matchesEntryPassOpeningTime() {
        assertThat(EntryOpenSweep.ENTRY_OPENS_BEFORE_START)
                .isEqualTo(EntryPassService.ENTRY_OPENS_BEFORE_START);
    }
}
