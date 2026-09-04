package com.ssafy.timo.global.exception;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.matchesPattern;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * GlobalExceptionHandler 슬라이스 테스트.
 *
 * <p>테스트 전용 컨트롤러를 등록해 실제 MVC 파이프라인(HandlerExceptionResolver -> @RestControllerAdvice)을
 * 그대로 태운 뒤, 응답이 합의된 스키마와 정확히 일치하는지 검증한다.
 * 시큐리티 필터는 예외 처리 자체와 무관하므로 비활성화한다.
 */
@WebMvcTest(controllers = GlobalExceptionHandlerTest.TestController.class)
@AutoConfigureMockMvc(addFilters = false)
@Import(GlobalExceptionHandlerTest.TestControllerConfig.class)
class GlobalExceptionHandlerTest {

    private static final String TIMESTAMP_PATTERN = "\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}";

    @Autowired
    private MockMvc mvc;

    @Test
    @DisplayName("에러 응답은 합의된 7개 필드로만 구성된다")
    void errorResponse_matchesAgreedSchemaExactly() throws Exception {
        mvc.perform(get("/test/duplicate"))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.type").value("about:blank"))
                .andExpect(jsonPath("$.title").value("Bad Request"))
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.instance").value("/test/duplicate"))
                .andExpect(jsonPath("$.errorMessage").value(TestController.DUPLICATE_MESSAGE))
                .andExpect(jsonPath("$.timestamp").value(matchesPattern(TIMESTAMP_PATTERN)))
                // 실제 던져진 예외 클래스명이 그대로 찍힌다.
                .andExpect(jsonPath("$.exception").value("DuplicateComponentException"))
                // 스키마 밖 필드가 새로 붙지 않았는지 확인한다.
                .andExpect(jsonPath("$.length()").value(7))
                .andExpect(jsonPath("$.detail").doesNotExist())
                .andExpect(jsonPath("$.errorCode").doesNotExist());
    }

    @Test
    @DisplayName("BusinessException 은 에러 코드의 상태와 기본 메시지로 응답한다")
    void businessException_respondsWithErrorCodeDefaults() throws Exception {
        mvc.perform(get("/test/business-exception"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.title").value("Internal Server Error"))
                .andExpect(jsonPath("$.status").value(500))
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INTERNAL_SERVER_ERROR.getMessage()))
                .andExpect(jsonPath("$.exception").value("BusinessException"));
    }

    @Test
    @DisplayName("상황별 메시지를 넘긴 BusinessException 은 errorMessage 가 덮인다")
    void businessException_usesOverriddenMessage() throws Exception {
        mvc.perform(get("/test/business-exception/custom"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value(TestController.CUSTOM_MESSAGE));
    }

    @Test
    @DisplayName("도메인별 에러 코드도 BaseErrorCode 구현체면 그대로 처리된다")
    void businessException_acceptsDomainErrorCode() throws Exception {
        mvc.perform(get("/test/business-exception/domain"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.title").value("Not Found"))
                .andExpect(jsonPath("$.errorMessage").value("테스트 대상을 찾을 수 없습니다."));
    }

    @Test
    @DisplayName("@Valid 검증 실패 시 errors 배열이 추가로 붙는다")
    void validationFailure_includesFieldErrors() throws Exception {
        mvc.perform(post("/test/validate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"  \",\"quantity\":0}"))
                .andExpect(status().isBadRequest())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INVALID_INPUT_VALUE.getMessage()))
                .andExpect(jsonPath("$.exception").value("MethodArgumentNotValidException"))
                .andExpect(jsonPath("$.errors.length()").value(2))
                .andExpect(jsonPath("$.errors[*].field").value(containsInAnyOrder("name", "quantity")))
                .andExpect(jsonPath("$.errors[0].reason").isNotEmpty())
                // 검증 실패에서만 errors 가 붙으므로 필드는 8개가 된다.
                .andExpect(jsonPath("$.length()").value(8));
    }

    @Test
    @DisplayName("검증을 통과한 요청은 예외 핸들러의 영향을 받지 않는다")
    void validRequest_isNotAffectedByHandler() throws Exception {
        mvc.perform(post("/test/validate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"좌석A\",\"quantity\":2}"))
                .andExpect(status().isOk())
                .andExpect(content().string("ok"));
    }

    @Test
    @DisplayName("처리되지 않은 예외는 내부 정보를 숨기고 고정 메시지로 응답한다")
    void unhandledException_hidesInternalDetails() throws Exception {
        mvc.perform(get("/test/runtime-exception"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INTERNAL_SERVER_ERROR.getMessage()))
                .andExpect(jsonPath("$.exception").value("IllegalStateException"))
                // 원본 메시지가 응답에 새어 나가면 안 된다.
                .andExpect(content().string(not(containsString(TestController.LEAKY_MESSAGE))));
    }

    @Test
    @DisplayName("Spring 내장 예외 응답도 같은 스키마로 통일된다")
    void springBuiltInException_isDecoratedWithSameSchema() throws Exception {
        // POST 전용 엔드포인트에 GET -> HttpRequestMethodNotSupportedException (405)
        mvc.perform(get("/test/validate"))
                .andExpect(status().isMethodNotAllowed())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_PROBLEM_JSON))
                .andExpect(jsonPath("$.type").value("about:blank"))
                .andExpect(jsonPath("$.status").value(405))
                .andExpect(jsonPath("$.errorMessage").isNotEmpty())
                .andExpect(jsonPath("$.timestamp").value(matchesPattern(TIMESTAMP_PATTERN)))
                .andExpect(jsonPath("$.exception").value("HttpRequestMethodNotSupportedException"))
                .andExpect(jsonPath("$.detail").doesNotExist())
                .andExpect(jsonPath("$.length()").value(7));
    }

    @TestConfiguration
    static class TestControllerConfig {

        @Bean
        TestController testController() {
            return new TestController();
        }
    }

    @RestController
    static class TestController {

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
        String validate(@Valid @RequestBody TestRequest request) {
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

    record TestRequest(@NotBlank String name, @Min(1) int quantity) {
    }
}
