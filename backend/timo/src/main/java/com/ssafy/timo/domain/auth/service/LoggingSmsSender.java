package com.ssafy.timo.domain.auth.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

/**
 * 문자를 보내지 않고 인증 코드를 로그로만 남기는 구현체. {@code local} 과 {@code test} 에서 뜬다.
 *
 * <p>{@code test} 를 빠뜨리면 안 된다. 통합 테스트는 {@code @ActiveProfiles("test")} 로 도는데
 * 여기서 {@link SolapiSmsSender} 가 뜨면 컨텍스트가 아예 로딩되지 않는다.
 *
 * <p>{@link SolapiSmsSender} 와 조건이 서로 여집합이어야 한다는 점은 그쪽 주석 참고.
 */
@Slf4j
@Component
@Profile({"local", "test"})
public class LoggingSmsSender implements SmsSender {

    @Override
    public void sendVerificationCode(String phoneNumber, String code) {
        log.warn("[SMS NOT SENT] phoneNumber={}, code={}", phoneNumber, code);
    }
}
