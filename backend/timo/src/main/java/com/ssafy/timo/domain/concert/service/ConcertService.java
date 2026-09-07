package com.ssafy.timo.domain.concert.service;

import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertDetailResponseDto;

public interface ConcertService {
    CommandConcertResponseDto create(CommandConcertRequestDto request);

    ConcertDetailResponseDto find(Long concertId);
}
