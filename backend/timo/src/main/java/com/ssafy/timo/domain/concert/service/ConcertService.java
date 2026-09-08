package com.ssafy.timo.domain.concert.service;

import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertDetailResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertListRequestDto;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import org.springframework.data.web.PagedModel;

public interface ConcertService {
    CommandConcertResponseDto create(CommandConcertRequestDto request);

    ConcertDetailResponseDto find(Long concertId);

    PagedModel<ConcertSummaryResponseDto> findAll(ConcertListRequestDto request);
}
