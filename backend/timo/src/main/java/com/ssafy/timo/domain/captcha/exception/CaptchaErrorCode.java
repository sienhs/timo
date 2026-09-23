package com.ssafy.timo.domain.captcha.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/**
 * 캡차 에러 코드.
 *
 * <p>응답 본문에는 이 상수명이 실리지 않는다({@code BaseErrorCode.name()} 은 로그 식별용이다).
 * 앱이 상황을 가려야 할 때 보는 것은 상태 코드와 Problem Details 의 {@code exception} 이므로,
 * 코드마다 전용 예외를 따로 둔다 - {@code GoodsErrorCode} 와 같은 방식이다.
 *
 * <p><b>403 이 둘인 이유.</b> {@link #CAPTCHA_REQUIRED} 는 "캡차를 풀고 오라"는 뜻이고
 * {@link #CAPTCHA_KEY_OWNER_MISMATCH} 는 "남의 캡차 키를 들고 왔다"는 뜻이다. 앞의 것은 앱이
 * 캡차 화면을 띄워 복구할 수 있고 뒤의 것은 정상적인 앱에서는 나올 수 없는 요청이라, 같은 상태
 * 코드라도 앱이 다르게 반응해야 한다.
 *
 * <p><b>만료와 오답을 한 코드로 묶지 않는다.</b> 키는 1회용이라 오답이어도 폐기되는데,
 * 그 뒤 재요청은 {@link #CAPTCHA_KEY_NOT_FOUND} 가 된다. 앱 입장에서 "틀렸으니 다시 입력"과
 * "키가 죽었으니 새로 발급"은 다음 행동이 다르다.
 */
@Getter
@RequiredArgsConstructor
public enum CaptchaErrorCode implements BaseErrorCode {

    /** 입력값이 캡차 이미지와 다르다. 키는 이미 폐기됐으므로 새로 발급받아야 한다. */
    CAPTCHA_MISMATCH(HttpStatus.BAD_REQUEST, "캡차 입력값이 올바르지 않습니다."),

    /** 다른 사용자에게 발급된 캡차 키다. */
    CAPTCHA_KEY_OWNER_MISMATCH(HttpStatus.FORBIDDEN, "다른 사용자에게 발급된 캡차입니다."),

    /** 키가 없거나, 만료됐거나, 이미 한 번 쓰였다. 셋을 가르지 않는다. */
    CAPTCHA_KEY_NOT_FOUND(HttpStatus.NOT_FOUND, "만료되었거나 존재하지 않는 캡차입니다."),

    /** 이 공연에 대한 캡차 통과 기록이 없거나 유효 시간이 지났다. */
    CAPTCHA_REQUIRED(HttpStatus.FORBIDDEN, "캡차 확인이 필요합니다."),

    /** 1분 안에 캡차를 너무 많이 받아 갔다. 네이버 API 호출 한도를 지키기 위한 제한이다. */
    CAPTCHA_TOO_MANY_REQUESTS(HttpStatus.TOO_MANY_REQUESTS, "캡차 요청이 너무 많습니다. 잠시 후 다시 시도해 주세요."),

    /**
     * 네이버 캡차 API 호출이 실패했다. 우리 잘못도 사용자 잘못도 아니라는 뜻의 502 다.
     *
     * <p>사유(타임아웃·인증 실패·응답 형식)를 응답에 싣지 않는다. 설정이 잘못됐는지 상대가 죽었는지는
     * 밖에서 알 필요가 없고, 알려 주면 캡차를 우회하려는 쪽에 힌트가 된다.
     */
    CAPTCHA_PROVIDER_ERROR(HttpStatus.BAD_GATEWAY, "캡차 서비스를 이용할 수 없습니다. 잠시 후 다시 시도해 주세요.");

    private final HttpStatus status;
    private final String message;
}
