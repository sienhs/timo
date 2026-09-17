package com.ssafy.timo.domain.transfer.service;

import com.ssafy.timo.domain.transfer.dto.MarketHoursResponseDto;
import com.ssafy.timo.domain.transfer.exception.MarketClosedException;
import com.ssafy.timo.domain.transfer.exception.MarketOpenException;
import com.ssafy.timo.global.config.MarketHoursProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.time.Clock;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

/**
 * 양도 마켓 운영 시간 판정.
 *
 * <p><b>등록은 언제나 받고, 남의 매물이 보이는 조회와 구매만 창 안에서 연다.</b> 닫힌 시간에 등록한
 * 매물은 {@code LISTED} 로 저장돼 있다가 20:00 에 조회가 열리면서 한꺼번에 드러난다 — 별도 대기
 * 상태나 일괄 전이 없이 "일괄로 올라가는" 경험이 된다. 가격 수정은 반대로 창 밖에서만 받는다
 * ({@link #requireClosed()}). 거래 중에 가격이 흔들리면 구매자가 본 값이 상세에서 달라진다.
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

    /** 열려 있으면 409. 메시지에 마감 시각이 실린다. */
    public void requireClosed() {
        MarketHoursResponseDto status = status();
        if (status.open()) {
            throw new MarketOpenException(status.closesAt());
        }
    }
}
