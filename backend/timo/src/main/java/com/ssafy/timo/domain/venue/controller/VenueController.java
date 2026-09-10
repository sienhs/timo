package com.ssafy.timo.domain.venue.controller;

import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.dto.CommandVenueResponseDto;
import com.ssafy.timo.domain.venue.service.VenueService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;

/**
 * 공연장 API (v1, 실제 구현).
 *
 * <p>엔드포인트 매핑과 검증 규약은 {@link VenueApi} 에 있다. 이 클래스는 버전 경로를 정하고
 * 서비스에 위임만 한다. 프론트 연동용 스텁은 {@code /api/v0/venues} 에 같은 규약으로 떠 있다.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping(VenueController.BASE_PATH)
@RequiredArgsConstructor
public class VenueController implements VenueApi {

    /** Location 헤더를 만들 때도 재사용하도록 상수로 둔다. */
    static final String BASE_PATH = "/api/v1/venues";

    private final VenueService venueService;

    @Override
    public ResponseEntity<CommandVenueResponseDto> register(CommandVenueRequestDto request) {
        CommandVenueResponseDto response = venueService.register(request);

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/" + response.id()))
                .body(response);
    }
}
