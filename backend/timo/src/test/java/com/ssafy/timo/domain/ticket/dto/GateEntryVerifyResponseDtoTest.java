package com.ssafy.timo.domain.ticket.dto;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyResponseDto.HolderInfo;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyResponseDto.SeatInfo;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 직렬화된 모양을 고정한다. 게이트 앱이 이 JSON 을 그대로 파싱하고, 추가 필드는 전부
 * "없을 수 있는 값" 이라는 전제로 optional 파싱하기 때문이다.
 *
 * <p>record 에 필드를 늘리면 {@code {"admitted":true,"seat":null}} 이 나가는 사고가 흔한데,
 * 앱의 {@code admitted is! bool} 방어에는 걸리지 않으면서 화면에 빈 줄만 생긴다.
 */
class GateEntryVerifyResponseDtoTest {

    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    @DisplayName("해당 없는 필드는 null 이 아니라 아예 나타나지 않는다")
    void omitsAbsentFields() throws Exception {
        String json = objectMapper.writeValueAsString(
                GateEntryVerifyResponseDto.reject(GateRejectReason.EXPIRED));

        assertThat(json).isEqualTo("{\"admitted\":false,\"reasonCode\":\"EXPIRED\"}");
    }

    @Test
    @DisplayName("허용이면 거절 사유 없이 좌석과 예매자를 싣는다")
    void serializesAdmitted() throws Exception {
        String json = objectMapper.writeValueAsString(GateEntryVerifyResponseDto.admit(
                new SeatInfo("B구역", 14, 12), new HolderInfo("장민석", "010****5678")));

        assertThat(json).isEqualTo("{\"admitted\":true,"
                + "\"seat\":{\"sectionName\":\"B구역\",\"seatNo\":14,\"seatCol\":12},"
                + "\"holder\":{\"name\":\"장민석\",\"maskedPhoneNumber\":\"010****5678\"}}");
    }

    @Test
    @DisplayName("중복 스캔은 좌석만 싣고 예매자는 싣지 않는다")
    void serializesAlreadyUsed() throws Exception {
        String json = objectMapper.writeValueAsString(
                GateEntryVerifyResponseDto.alreadyUsed(new SeatInfo("B구역", 14, 12)));

        assertThat(json).isEqualTo("{\"admitted\":false,\"reasonCode\":\"ALREADY_USED\","
                + "\"seat\":{\"sectionName\":\"B구역\",\"seatNo\":14,\"seatCol\":12}}");
    }
}
