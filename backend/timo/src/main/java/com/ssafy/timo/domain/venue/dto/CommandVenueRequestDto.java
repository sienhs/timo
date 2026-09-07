package com.ssafy.timo.domain.venue.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CommandVenueRequestDto(

        @NotBlank(message = "공연장명은 필수입니다.")
        @Size(max = 10, message = "공연장명은 10자 이하여야 합니다.")
        String name,

        @NotBlank(message = "공연장 주소는 필수입니다.")
        String address,

        @Min(value = 0, message = "총 좌석 수는 0 이상이어야 합니다.")
        int totalSeatCount
) {
}
