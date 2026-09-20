package com.ssafy.timo.domain.notification.controller;

import com.ssafy.timo.domain.notification.scheduler.NotificationSweepScheduler;
import com.ssafy.timo.domain.notification.scheduler.NotificationSweepScheduler.SweepResult;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Profile;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 알림 스윕을 바로 돌려 보는 개발용 진입점. <b>로컬과 시연 환경에만 뜬다.</b>
 *
 * <p>시드 공연의 날짜는 알림이 나가는 시간 창에 걸리지 않아서, 가만히 두면 로컬에서는 알림이 하나도 생기지
 * 않는다. 시드를 알림에 맞게 고치면 시드가 지키는 조건과 부딪치므로, 대신 <b>기준 시각을 지정해서 그 시각인
 * 것처럼</b> 스윕을 돌린다. 예를 들어 어떤 공연의 오픈이 9월 27일 20시이면 {@code at=2026-09-20T09:00:00} 으로
 * 돌려 7일 전 알림을 만든다. 시각을 주지 않으면 지금 시각으로 돈다.
 *
 * <p>운영에는 이 경로가 없다. {@code @Profile} 이 빈 자체를 만들지 않으므로 운영 프로필에서는 404 다. 시연
 * 환경에서는 로그인한 사용자라면 누구나 부를 수 있고, 회원 전체의 알림이 만들어진다. 시연 데이터를 위한
 * 경로라 그대로 둔다.
 *
 * <p>스케줄러와 같은 코드를 탄다. 저장, 중복 방지, 푸시 발송 모두 실제와 같이 동작하고, 같은 시각으로 두 번
 * 부르면 두 번째는 0 건이다.
 */
@Profile({"local", "demo"})
@RestController
@RequestMapping("/api/v1/dev/notifications")
@RequiredArgsConstructor
public class DevNotificationController {

    private final NotificationSweepScheduler notificationSweepScheduler;
    private final Clock clock;

    /**
     * 모든 스윕을 한 번씩 돌린다.
     *
     * @param at 기준 시각(예: {@code 2026-09-20T09:00:00}). 없으면 지금
     */
    @PostMapping("/sweep")
    public ResponseEntity<SweepResponse> sweep(
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime at) {
        LocalDateTime now = at != null ? at : LocalDateTime.now(clock);
        return ResponseEntity.ok(new SweepResponse(now, notificationSweepScheduler.runOnce(now)));
    }

    /**
     * @param at     스윕이 기준으로 삼은 시각. 지정하지 않았으면 지금 시각이다
     * @param sweeps 스윕별 결과. 실패한 스윕도 들어 있다
     */
    public record SweepResponse(LocalDateTime at, List<SweepResult> sweeps) {
    }
}
