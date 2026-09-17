package com.ssafy.timo.domain.transfer.service;

import com.ssafy.timo.domain.transfer.dto.MarketHoursResponseDto;
import com.ssafy.timo.domain.transfer.exception.MarketClosedException;
import com.ssafy.timo.global.config.MarketHoursProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

/**
 * 양도 마켓 운영 시간 판정. 등록·가격 수정·구매가 {@link #requireOpen()} 을 맨 앞에서 부른다.
 *
 * <p>판정의 근거는 서버 {@link Clock} 하나다. 앱이 자기 시계로 화면을 잠그는 것은 안내이지
 * 접근 제어가 아니라서, 기기 시각을 돌리거나 API 를 직접 치면 그대로 뚫린다.
 *
 * <p>초 단위로 자른 뒤 비교한다. 닫는 시각이 23:59:59 인데 23:59:59.4 를 "지났다" 고 보면
 * 규칙에 적힌 마지막 1초가 사실상 없어진다.
 */
@Service
@RequiredArgsConstructor
public class MarketHoursService {

    private final MarketHoursProperties properties;
    private final Clock clock;

    /** 지금 열려 있는지와, 앱이 카운트다운을 그릴 창의 시각. */
    public MarketHoursResponseDto status() {
        LocalDateTime now = LocalDateTime.now(clock).truncatedTo(ChronoUnit.SECONDS);
        LocalDate today = now.toLocalDate();
        LocalDateTime opensAt = today.atTime(properties.openAt());
        LocalDateTime closesAt = today.atTime(properties.closeAt());

        if (now.isAfter(closesAt)) {
            // 오늘 창은 끝났다. 다음 창은 내일이다.
            opensAt = opensAt.plusDays(1);
            closesAt = closesAt.plusDays(1);
        }
        boolean open = !now.isBefore(opensAt) && !now.isAfter(closesAt);

        return new MarketHoursResponseDto(open, now, opensAt, closesAt);
    }

    /** 닫혀 있으면 409. 메시지에 다음 여는 시각이 실린다. */
    public void requireOpen() {
        MarketHoursResponseDto status = status();
        if (!status.open()) {
            throw new MarketClosedException(status.opensAt());
        }
    }
}
