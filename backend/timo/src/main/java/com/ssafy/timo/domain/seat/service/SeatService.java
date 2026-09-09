package com.ssafy.timo.domain.seat.service;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldCancelResponseDto;
import com.ssafy.timo.domain.seat.dto.SeatHoldResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionListResponseDto;
import com.ssafy.timo.domain.seat.dto.SectionSeatListResponseDto;

public interface SeatService {
    CommandSeatResponseDto register(CommandSeatRequestDto request);

    SectionListResponseDto findSections(Long venueId);

    SectionSeatListResponseDto findSeats(Long sectionId);

    SeatHoldResponseDto hold(Long seatId);

    SeatHoldCancelResponseDto cancelHold(Long seatId);
}
