package com.ssafy.timo.support;

import com.ssafy.timo.domain.captcha.repository.CaptchaPassedStore;

/**
 * 통합 테스트에서 캡차를 통과한 상태를 직접 만든다.
 *
 * <p>{@code @RequireCaptcha} 가 붙은 엔드포인트(좌석 조회)를 호출하는 기존 테스트는, 실제 발급 →
 * 검증 흐름을 매번 타지 않고 이 헬퍼로 통과 기록만 바로 만든다. 흐름 자체(대기열 → 발급 → 검증 →
 * 좌석 조회 → 선점)를 확인하는 테스트는 이 헬퍼를 쓰지 않고 실제 API 를 순서대로 호출한다.
 *
 * <p>{@link Authenticated} 와 짝이다 - 통과 기록은 회원 단위라 인증 없이는 의미가 없다.
 */
public final class CaptchaPassed {

    private CaptchaPassed() {
    }

    /** 이 회원이 이 공연의 캡차를 통과한 것으로 만든다. */
    public static void grant(CaptchaPassedStore captchaPassedStore, Long concertId, Long memberId) {
        captchaPassedStore.markPassed(concertId, memberId);
    }
}
