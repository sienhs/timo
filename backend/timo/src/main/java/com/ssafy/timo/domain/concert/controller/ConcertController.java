package com.ssafy.timo.domain.concert.controller;

import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertDetailResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertListRequestDto;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.domain.concert.service.ConcertService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;

/**
 * 공연 API (v1, 실제 구현).
 *
 * <p>엔드포인트 매핑과 검증 규약은 {@link ConcertApi} 에 있다. 이 클래스는 버전 경로를 정하고
 * 서비스에 위임만 한다. 프론트 연동용 스텁은 {@code /api/v0/concerts} 에 같은 규약으로 떠 있다.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping(ConcertController.BASE_PATH)
@RequiredArgsConstructor
public class ConcertController implements ConcertApi {

    /** Location 헤더를 만들 때도 재사용하도록 상수로 둔다. */
    static final String BASE_PATH = "/api/v1/concerts";

    private final ConcertService concertService;

    @Override
    public ResponseEntity<CommandConcertResponseDto> create(CommandConcertRequestDto request) {
        CommandConcertResponseDto response = concertService.create(request);

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/" + response.id()))
                .body(response);
    }

    @Override
    public ResponseEntity<PagedModel<ConcertSummaryResponseDto>> findAll(ConcertListRequestDto request) {
        return ResponseEntity.ok(concertService.findAll(request));
    }

    @Override
    public ResponseEntity<ConcertDetailResponseDto> find(Long concertId) {
        return ResponseEntity.ok(concertService.find(concertId));
    }
}
