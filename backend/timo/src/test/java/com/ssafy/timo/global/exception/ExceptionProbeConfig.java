package com.ssafy.timo.global.exception;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * {@link GlobalExceptionHandler} 검증용 프로브 컨트롤러를 등록한다.
 *
 * <p>예외 처리 규약은 특정 도메인 API 가 아니라 "어떤 예외가 어떤 응답으로 바뀌는가"라는 횡단 규칙이다.
 * 도메인 컨트롤러로 검증하면 그 도메인이 마침 던지는 예외만 확인할 수 있어, 던질 예외를 직접 고르는
 * 전용 컨트롤러를 쓴다.
 *
 * <p>{@code com.ssafy.timo.support.IntegrationTest} 가 이 설정을 올린다. 이 설정만 특정 테스트에서
 * 따로 import 하면 그 테스트가 별도 컨텍스트를 쓰게 되므로, 공용 애노테이션에 함께 묶어 두었다.
 * 테스트 소스에만 있고 {@code /test/**} 경로만 점유하므로 운영 코드에는 영향이 없다.
 *
 * <p>{@link TestErrorCode} 가 패키지 전용이라 이 클래스도 같은 패키지에 둔다.
 */
@Configuration
public class ExceptionProbeConfig {

    /**
     * {@code @Configuration} 의 중첩 {@code @RestController} 는 멤버 클래스 스캔으로 자동 등록된다.
     * 여기에 {@code @Bean} 메서드까지 두면 같은 핸들러가 두 번 매핑돼 컨텍스트가 뜨지 않는다.
     */
    @RestController
    public static class ProbeController {

        static final String CUSTOM_MESSAGE = "좌석이 이미 선점되었습니다.";
        static final String DUPLICATE_MESSAGE = "이미 배치된 아이템이에요.";
        static final String LEAKY_MESSAGE = "jdbc password is hunter2";

        @GetMapping("/test/duplicate")
        String duplicate() {
            throw new DuplicateComponentException(DUPLICATE_MESSAGE);
        }

        @GetMapping("/test/business-exception")
        String businessException() {
            throw new BusinessException(ErrorCode.INTERNAL_SERVER_ERROR);
        }

        @GetMapping("/test/business-exception/custom")
        String businessExceptionWithCustomMessage() {
            throw new BusinessException(ErrorCode.INVALID_INPUT_VALUE, CUSTOM_MESSAGE);
        }

        @GetMapping("/test/business-exception/domain")
        String businessExceptionWithDomainErrorCode() {
            throw new BusinessException(TestErrorCode.TARGET_NOT_FOUND);
        }

        @PostMapping("/test/validate")
        String validate(@Valid @RequestBody ProbeRequest request) {
            return "ok";
        }

        @GetMapping("/test/runtime-exception")
        String runtimeException() {
            throw new IllegalStateException(LEAKY_MESSAGE);
        }
    }

    /**
     * 응답의 exception 필드에 구체적인 이름을 찍으려면 BusinessException 을 상속한다는 것을
     * 확인하기 위한 테스트 전용 예외.
     */
    static class DuplicateComponentException extends BusinessException {

        DuplicateComponentException(String message) {
            super(ErrorCode.INVALID_INPUT_VALUE, message);
        }
    }

    record ProbeRequest(@NotBlank String name,
                        @Min(1) int quantity,
                        ProbeGenre genre,
                        List<Integer> counts) {
    }

    /** 본문 매핑 단계의 enum 실패를 확인하기 위한 테스트 전용 enum. */
    enum ProbeGenre {
        ALPHA, BETA
    }
}
