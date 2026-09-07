package com.ssafy.timo.domain.concert.controller;

import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.service.ConcertService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
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
}
