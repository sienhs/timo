package com.ssafy.timo.domain.auth.service;

/**
 * 인증 문자 발송 창구.
 *
 * <p>구현체는 프로파일로 갈린다. 운영은 {@link SolapiSmsSender}(실제 발송),
 * 그 밖의 프로파일은 {@link LoggingSmsSender}(로그만). 두 조건은 서로 여집합이라
 * 어떤 프로파일에서도 구현체가 정확히 하나 뜬다.
 */
public interface SmsSender {

    void sendVerificationCode(String phoneNumber, String code);
}
