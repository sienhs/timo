package com.ssafy.timo.domain.ticket.controller;

import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyRequestDto;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyResponseDto;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

/**
 * 게이트 검표 API 규약.
 *
 * <p>매핑과 검증 애노테이션은 여기에만 둔다. 구현체는 클래스 레벨 {@code @RequestMapping} 으로
 * 버전 경로만 정한다. 자세한 이유는 {@link com.ssafy.timo.domain.venue.controller.VenueApi} 참고.
 */
public interface GateEntryApi {

    /**
     * QR 한 장을 검표해 입장 여부를 판정하고, 통과시켰다면 입장 처리까지 끝낸다.
     *
     * <p>GET 이 아니라 POST 다. 판정이 곧 소진이라 부를 때마다 서버 상태가 바뀐다 - 같은 QR 을 두 번
     * 보내면 두 번째는 {@code ALREADY_USED} 다. QR 문자열을 URL 에 싣지 않는 이유이기도 하다.
     * 경로는 접근 로그·프록시 로그에 그대로 남는데, 짧게나마 입장이 되는 값이다.
     *
     * <p>거절도 200 이다. 4xx/5xx 는 "판정을 못 했다"(네트워크·서버 문제) 는 뜻으로만 쓴다 -
     * {@link GateEntryVerifyResponseDto} 주석 참고.
     */
    @PostMapping("/entries/verify")
    ResponseEntity<GateEntryVerifyResponseDto> verify(@Valid @RequestBody GateEntryVerifyRequestDto request);
}
