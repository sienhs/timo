package com.ssafy.timo.domain.venue.dto;

public record CommandVenueResponseDto(
        Long id,
        String name,
        String address,
        int totalSeatCount
) {
}
