package com.ssafy.timo.stub;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.web.bind.annotation.RestController;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 프론트 연동용 스텁 컨트롤러 표시.
 *
 * <p>{@code @RestController} 에 {@code api.stub.enabled=true} 조건을 합친 것이다. 스텁 클래스마다
 * 조건을 따로 적으면 하나가 빠졌을 때 배포 환경에 스텁이 올라가는데, 이 애노테이션 하나만 붙이게 하면
 * 그 실수가 생길 자리가 없다.
 *
 * <p>값은 {@code application-local.yml} 이 {@code true}, {@code application-prod.yml} 이 {@code false}
 * 로 둔다. 다른 환경(예: CI 의 별도 개발 서버)에서 켜야 하면 환경 변수 {@code API_STUB_ENABLED=true}
 * 로 덮어쓴다.
 */
@Documented
@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
@RestController
@ConditionalOnProperty(prefix = "api.stub", name = "enabled", havingValue = "true")
public @interface StubController {
}
