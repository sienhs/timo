package com.ssafy.timo.stub.venue;

import com.ssafy.timo.domain.venue.controller.VenueApi;
import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.dto.CommandVenueResponseDto;
import com.ssafy.timo.stub.StubController;
import com.ssafy.timo.stub.StubFixtures;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;

import java.net.URI;
import java.util.concurrent.atomic.AtomicLong;

/**
 * 공연장 API 스텁 (v0).
 *
 * <p>요청값을 그대로 돌려주고 id 만 새로 매긴다. 공연장명 중복(409)은 재현하지 않는다.
 * 아직 실제 API 에도 그 실패 케이스가 명세돼 있지 않기 때문이다.
 */
@StubController
@RequestMapping(VenueStubController.BASE_PATH)
public class VenueStubController implements VenueApi {

    static final String BASE_PATH = "/api/v0/venues";

    private final AtomicLong idSequence = new AtomicLong(StubFixtures.CREATED_ID_START);

    @Override
    public ResponseEntity<CommandVenueResponseDto> register(CommandVenueRequestDto request) {
        CommandVenueResponseDto response = new CommandVenueResponseDto(
                idSequence.getAndIncrement(),
                request.name(),
                request.address(),
                request.totalSeatCount());

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/" + response.id()))
                .body(response);
    }
}
