package com.ssafy.timo.domain.captcha.dto;

/**
 * 캡차 발급 응답.
 *
 * <p>이미지를 URL 이 아니라 본문에 base64 로 싣는다. 캡차 이미지는 한 번 쓰고 버리는 것이라
 * 저장소에 올려 URL 을 주면 정리할 대상만 늘고, 그 URL 이 인증 없이 열리면 캡차를 대신 풀어 주는
 * 자리가 된다.
 *
 * @param captchaKey 검증할 때 그대로 돌려줄 키
 * @param image      base64 로 인코딩한 이미지 바이트
 * @param imageType  {@code image} 를 그릴 때 쓸 MIME 타입
 * @param expiresIn  이 캡차가 유효한 시간(초)
 */
public record CaptchaIssueResponseDto(String captchaKey, String image, String imageType, long expiresIn) {
}
