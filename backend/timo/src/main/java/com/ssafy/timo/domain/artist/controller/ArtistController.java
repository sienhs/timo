package com.ssafy.timo.domain.artist.controller;

import com.ssafy.timo.domain.artist.dto.ArtistListRequestDto;
import com.ssafy.timo.domain.artist.dto.ArtistSummaryResponseDto;
import com.ssafy.timo.domain.artist.service.ArtistService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 아티스트 API (v1, 실제 구현).
 *
 * <p>엔드포인트 매핑과 검증 규약은 {@link ArtistApi} 에 있다. 이 클래스는 버전 경로를 정하고
 * 서비스에 위임만 한다.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping("/api/v1/artists")
@RequiredArgsConstructor
public class ArtistController implements ArtistApi {

    private final ArtistService artistService;

    @Override
    public ResponseEntity<PagedModel<ArtistSummaryResponseDto>> findAll(ArtistListRequestDto request) {
        return ResponseEntity.ok(artistService.findAll(request));
    }
}
