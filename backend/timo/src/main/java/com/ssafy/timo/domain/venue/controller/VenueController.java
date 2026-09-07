package com.ssafy.timo.domain.venue.controller;

import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.dto.CommandVenueResponseDto;
import com.ssafy.timo.domain.venue.service.VenueService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;

/**
 * 공연장 API.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping(VenueController.BASE_PATH)
@RequiredArgsConstructor
public class VenueController {

    /** Location 헤더를 만들 때도 재사용하도록 상수로 둔다. */
    static final String BASE_PATH = "/api/v1/venues";

    private final VenueService venueService;

    /** 공연장을 등록하고 생성된 리소스 위치를 Location 헤더로 알려준다. */
    @PostMapping
    public ResponseEntity<CommandVenueResponseDto> register(@Valid @RequestBody CommandVenueRequestDto request) {
        CommandVenueResponseDto response = venueService.register(request);

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/" + response.id()))
                .body(response);
    }
}
