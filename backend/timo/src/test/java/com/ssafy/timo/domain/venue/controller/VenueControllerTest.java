package com.ssafy.timo.domain.venue.controller;

import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.dto.CommandVenueResponseDto;
import com.ssafy.timo.domain.venue.exception.VenueNameDuplicatedException;
import com.ssafy.timo.domain.venue.service.VenueService;
import com.ssafy.timo.global.exception.ErrorCode;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.never;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * VenueController 슬라이스 테스트.
 *
 * <p>인증/인가 정책이 아직 없으므로 시큐리티 필터는 비활성화하고 MVC 파이프라인만 검증한다.
 */
@WebMvcTest(VenueController.class)
@AutoConfigureMockMvc(addFilters = false)
class VenueControllerTest {

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private VenueService venueService;

    @Test
    @DisplayName("공연장을 등록하면 201 과 함께 생성된 리소스 위치를 반환한다")
    void register_returnsCreatedWithLocation() throws Exception {
        given(venueService.register(any(CommandVenueRequestDto.class)))
                .willReturn(new CommandVenueResponseDto(1L, "고척돔", "서울시 구로구 경인로 430", 16000));

        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"고척돔","address":"서울시 구로구 경인로 430","totalSeatCount":16000}
                                """))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", "/api/v1/venues/1"))
                .andExpect(jsonPath("$.id").value(1))
                .andExpect(jsonPath("$.name").value("고척돔"))
                .andExpect(jsonPath("$.address").value("서울시 구로구 경인로 430"))
                .andExpect(jsonPath("$.totalSeatCount").value(16000));
    }

    @Test
    @DisplayName("요청 본문의 값이 그대로 서비스로 전달된다")
    void register_passesRequestToService() throws Exception {
        given(venueService.register(any(CommandVenueRequestDto.class)))
                .willReturn(new CommandVenueResponseDto(1L, "소극장", "서울시 종로구 대학로 12", 0));

        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"소극장","address":"서울시 종로구 대학로 12","totalSeatCount":0}
                                """))
                .andExpect(status().isCreated());

        ArgumentCaptor<CommandVenueRequestDto> requestCaptor =
                ArgumentCaptor.forClass(CommandVenueRequestDto.class);
        then(venueService).should().register(requestCaptor.capture());

        CommandVenueRequestDto captured = requestCaptor.getValue();
        assertThat(captured.name()).isEqualTo("소극장");
        assertThat(captured.address()).isEqualTo("서울시 종로구 대학로 12");
        assertThat(captured.totalSeatCount()).isZero();
    }

    @Test
    @DisplayName("공연장명이 공백이면 400 과 필드 에러를 반환하고 서비스는 호출되지 않는다")
    void register_rejectsBlankName() throws Exception {
        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"  ","address":"서울시 구로구 경인로 430","totalSeatCount":16000}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errorMessage").value(ErrorCode.INVALID_INPUT_VALUE.getMessage()))
                .andExpect(jsonPath("$.errors[0].field").value("name"))
                .andExpect(jsonPath("$.errors[0].reason").value("공연장명은 필수입니다."));

        then(venueService).should(never()).register(any());
    }

    @Test
    @DisplayName("공연장명이 10자를 넘으면 400 을 반환한다")
    void register_rejectsTooLongName() throws Exception {
        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"올림픽공원 체조경기장","address":"서울시 송파구 올림픽로 424","totalSeatCount":5000}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("name"))
                .andExpect(jsonPath("$.errors[0].reason").value("공연장명은 10자 이하여야 합니다."));

        then(venueService).should(never()).register(any());
    }

    @Test
    @DisplayName("주소가 비어 있으면 400 을 반환한다")
    void register_rejectsBlankAddress() throws Exception {
        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"고척돔","address":"","totalSeatCount":16000}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("address"))
                .andExpect(jsonPath("$.errors[0].reason").value("공연장 주소는 필수입니다."));

        then(venueService).should(never()).register(any());
    }

    @Test
    @DisplayName("총 좌석 수가 음수면 400 을 반환한다")
    void register_rejectsNegativeSeatCount() throws Exception {
        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"고척돔","address":"서울시 구로구 경인로 430","totalSeatCount":-1}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors[0].field").value("totalSeatCount"))
                .andExpect(jsonPath("$.errors[0].reason").value("총 좌석 수는 0 이상이어야 합니다."));

        then(venueService).should(never()).register(any());
    }

    @Test
    @DisplayName("중복된 공연장명이면 409 와 도메인 에러 메시지를 반환한다")
    void register_returnsConflictOnDuplicatedName() throws Exception {
        willThrow(new VenueNameDuplicatedException("고척돔"))
                .given(venueService).register(any(CommandVenueRequestDto.class));

        mvc.perform(post("/api/v1/venues")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"name":"고척돔","address":"서울시 구로구 경인로 430","totalSeatCount":16000}
                                """))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.status").value(409))
                .andExpect(jsonPath("$.errorMessage").value("이미 등록된 공연장명입니다. (고척돔)"))
                .andExpect(jsonPath("$.exception").value("VenueNameDuplicatedException"));
    }
}
