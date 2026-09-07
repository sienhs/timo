package com.ssafy.timo.domain.venue.service;

import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.dto.CommandVenueResponseDto;

public interface VenueService {
    CommandVenueResponseDto register(CommandVenueRequestDto request);
}
