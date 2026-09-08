package com.ssafy.timo.domain.auth.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

@Slf4j
@Component
// @Profile("local")
@Profile({"local", "test"})
public class LoggingSmsSender implements SmsSender {

    @Override
    public void sendVerificationCode(String phoneNumber, String code) {
        log.warn("[SMS NOT SENT] phoneNumber={}, code={}", phoneNumber, code);
    }
}
