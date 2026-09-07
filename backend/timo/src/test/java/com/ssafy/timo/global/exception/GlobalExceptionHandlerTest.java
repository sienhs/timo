package com.ssafy.timo.global.exception;

import com.ssafy.timo.support.IntegrationTest;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static com.ssafy.timo.global.exception.ExceptionProbeConfig.ProbeController.CUSTOM_MESSAGE;
import static com.ssafy.timo.global.exception.ExceptionProbeConfig.ProbeController.DUPLICATE_MESSAGE;
import static com.ssafy.timo.global.exception.ExceptionProbeConfig.ProbeController.LEAKY_MESSAGE;
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
 * GlobalExceptionHandler 통합 테스트.
 *
 * <p>{@link ExceptionProbeConfig} 의 프로브 컨트롤러로 실제 MVC 파이프라인
 * (HandlerExceptionResolver -> @RestControllerAdvice)을 그대로 태운 뒤,
 * 응답이 합의된 스키마와 정확히 일치하는지 검증한다.
 */
@IntegrationTest
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
                .andExpect(jsonPath("$.errorMessage").value(DUPLICATE_MESSAGE))
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
                .andExpect(jsonPath("$.errorMessage").value(CUSTOM_MESSAGE));
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
    @DisplayName("정의되지 않은 enum 값이면 어느 필드가 왜 틀렸는지 알려준다")
    void unknownEnumValue_reportsFieldAndAllowedValues() throws Exception {
        mvc.perform(post("/test/validate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"좌석A\",\"quantity\":1,\"genre\":\"GAMMA\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INVALID_INPUT_VALUE.getMessage()))
                .andExpect(jsonPath("$.exception").value("HttpMessageNotReadableException"))
                .andExpect(jsonPath("$.errors.length()").value(1))
                .andExpect(jsonPath("$.errors[0].field").value("genre"))
                .andExpect(jsonPath("$.errors[0].reason")
                        .value("허용되지 않는 값입니다: GAMMA (가능한 값: ALPHA, BETA)"))
                .andExpect(jsonPath("$.length()").value(8));
    }

    @Test
    @DisplayName("배열 원소의 타입이 틀리면 몇 번째인지까지 알려준다")
    void typeMismatchInArray_reportsIndexedPath() throws Exception {
        mvc.perform(post("/test/validate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"좌석A\",\"quantity\":1,\"counts\":[1,\"틀린값\"]}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("counts[1]"))
                .andExpect(jsonPath("$.errors[0].reason").value("값의 형식이 올바르지 않습니다."));
    }

    @Test
    @DisplayName("JSON 자체가 깨졌으면 필드를 특정할 수 없으므로 errors 를 붙이지 않는다")
    void malformedJson_hasNoFieldErrors() throws Exception {
        mvc.perform(post("/test/validate")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\": "))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.exception").value("HttpMessageNotReadableException"))
                .andExpect(jsonPath("$.errors").doesNotExist())
                .andExpect(jsonPath("$.length()").value(7));
    }

    @Test
    @DisplayName("처리되지 않은 예외는 내부 정보를 숨기고 고정 메시지로 응답한다")
    void unhandledException_hidesInternalDetails() throws Exception {
        mvc.perform(get("/test/runtime-exception"))
                .andExpect(status().isInternalServerError())
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INTERNAL_SERVER_ERROR.getMessage()))
                .andExpect(jsonPath("$.exception").value("IllegalStateException"))
                // 원본 메시지가 응답에 새어 나가면 안 된다.
                .andExpect(content().string(not(containsString(LEAKY_MESSAGE))));
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
}
