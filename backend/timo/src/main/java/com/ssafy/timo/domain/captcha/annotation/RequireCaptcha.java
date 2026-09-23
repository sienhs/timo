package com.ssafy.timo.domain.captcha.annotation;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 이 핸들러를 호출하려면 먼저 캡차를 통과했어야 한다.
 *
 * <p>통과 단위는 공연({@code concertId})이다 - 원안의 회차 대신이다
 * ({@code docs/BE_CAPTCHA_TASK_BREAKDOWN.md} 0-1 참고). 그 값을 요청 어디서 어떤 이름으로 꺼낼지는
 * 엔드포인트마다 다르다. 좌석 조회(B9)는 쿼리 파라미터로 받으므로, 원안의 "path variable 에서
 * 꺼낸다" 하나만으로는 부족해 속성으로 파라미터 이름과 출처를 지정할 수 있게 했다.
 *
 * <p>{@code RequireCaptchaInterceptor} 가 읽는다. 인증 필터 뒤, 컨트롤러 인자 바인딩 앞에서 실행된다.
 */
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.METHOD)
public @interface RequireCaptcha {

    /** 공연 id 를 담은 요청 파라미터 이름. */
    String paramName() default "concertId";

    /** 그 파라미터를 요청 어디서 꺼낼지. */
    ParamSource paramSource() default ParamSource.QUERY;

    enum ParamSource {
        /** 쿼리 파라미터. 좌석 조회가 이 경우다. */
        QUERY,
        /** path variable. */
        PATH_VARIABLE
    }
}
