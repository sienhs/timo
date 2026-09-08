package com.ssafy.timo.domain.concert.controller;

import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertDetailResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertListRequestDto;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.domain.concert.service.ConcertService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;

/**
 * 공연 API.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping(ConcertController.BASE_PATH)
@RequiredArgsConstructor
public class ConcertController {

    /** Location 헤더를 만들 때도 재사용하도록 상수로 둔다. */
    static final String BASE_PATH = "/api/v1/concerts";

    private final ConcertService concertService;

    /** 공연을 생성하고 생성된 리소스 위치를 Location 헤더로 알려준다. */
    @PostMapping
    public ResponseEntity<CommandConcertResponseDto> create(@Valid @RequestBody CommandConcertRequestDto request) {
        CommandConcertResponseDto response = concertService.create(request);

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/" + response.id()))
                .body(response);
    }

    /**
     * 조건에 맞는 공연 목록을 페이지 단위로 조회한다.
     *
     * <p>조건은 모두 선택값이라 {@code GET /api/v1/concerts} 만 호출해도 된다. 상세 조회와 달리
     * 조회수는 올라가지 않는다.
     */
    @GetMapping
    public ResponseEntity<PagedModel<ConcertSummaryResponseDto>> findAll(@Valid @ModelAttribute ConcertListRequestDto request) {
        return ResponseEntity.ok(concertService.findAll(request));
    }

    /** 공연 상세를 조회한다. 조회할 때마다 조회수가 1 증가한다. */
    @GetMapping("/{concertId}")
    public ResponseEntity<ConcertDetailResponseDto> find(@PathVariable Long concertId) {
        return ResponseEntity.ok(concertService.find(concertId));
    }
}
