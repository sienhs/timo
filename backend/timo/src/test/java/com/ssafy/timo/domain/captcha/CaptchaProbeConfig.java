package com.ssafy.timo.domain.captcha;

import com.ssafy.timo.domain.captcha.annotation.RequireCaptcha;
import com.ssafy.timo.domain.captcha.annotation.RequireCaptcha.ParamSource;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * {@code RequireCaptchaInterceptor} 검증용 프로브 컨트롤러.
 *
 * <p>실제 좌석 조회(B9)를 붙이기 전에, 인터셉터 자체의 동작 - 쿼리 파라미터·path variable 양쪽에서
 * 값을 꺼내는지, 애노테이션이 없으면 그냥 통과시키는지, 통과 기록이 없으면 막는지 - 를 도메인 API 와
 * 무관하게 확인한다. {@code ExceptionProbeConfig} 와 같은 이유다.
 */
@Configuration
public class CaptchaProbeConfig {

    @RestController
    public static class ProbeController {

        /** 좌석 조회와 같은 모양 - 쿼리 파라미터 {@code concertId}. */
        @RequireCaptcha
        @GetMapping("/test/captcha/query")
        String byQuery(@RequestParam Long concertId) {
            return "ok";
        }

        /** path variable 로 받는 엔드포인트도 있을 수 있어 이쪽도 확인한다. */
        @RequireCaptcha(paramName = "concertId", paramSource = ParamSource.PATH_VARIABLE)
        @GetMapping("/test/captcha/path/{concertId}")
        String byPathVariable(@PathVariable Long concertId) {
            return "ok";
        }

        /** 애노테이션이 없으면 캡차와 무관하게 항상 통과해야 한다. */
        @GetMapping("/test/captcha/unprotected")
        String unprotected() {
            return "ok";
        }
    }
}
