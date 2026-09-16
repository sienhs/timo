package com.ssafy.timo.domain.artist.service;

import com.ssafy.timo.domain.artist.dto.ArtistListRequestDto;
import com.ssafy.timo.domain.artist.dto.ArtistSummaryResponseDto;
import org.springframework.data.web.PagedModel;

public interface ArtistService {
    PagedModel<ArtistSummaryResponseDto> findAll(ArtistListRequestDto request);
}
