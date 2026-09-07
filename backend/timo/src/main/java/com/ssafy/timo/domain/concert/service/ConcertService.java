package com.ssafy.timo.domain.concert.service;

import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;

public interface ConcertService {
    CommandConcertResponseDto create(CommandConcertRequestDto request);
}
