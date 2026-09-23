package com.ssafy.timo.domain.captcha.dto;

/**
 * 캡차 검증 응답.
 *
 * @param expiresIn 이 통과 기록이 유효한 시간(초). {@code naver.captcha.passed-ttl} 과 같다
 */
public record CaptchaVerifyResponseDto(long expiresIn) {
}
