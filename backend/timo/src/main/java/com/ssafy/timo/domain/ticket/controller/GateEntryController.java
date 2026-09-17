package com.ssafy.timo.domain.ticket.controller;

import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyRequestDto;
import com.ssafy.timo.domain.ticket.dto.GateEntryVerifyResponseDto;
import com.ssafy.timo.domain.ticket.service.GateEntryService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 게이트 검표 API (v1, 실제 구현).
 *
 * <p>엔드포인트 규약은 {@link GateEntryApi} 에 있다. 이 클래스는 버전 경로를 정하고 서비스에
 * 위임만 한다.
 *
 * <p><b>인증을 걸지 않는다(팀 결정).</b> 게이트 앱에 로그인 화면이 없어 지금은 보낼 토큰이 없다.
 * 그래서 QR 문자열을 아는 사람은 누구나 그 티켓을 {@code USED} 로 만들 수 있다 - 캡처 한 장이면
 * 관람객이 입구에 서기도 전에 표가 소진된다. 게이트 앱에 로그인이 생기면
 * {@code SecurityConfig} 의 {@code permitAll} 에서 이 경로를 빼는 것으로 닫힌다.
 */
@RestController
@RequestMapping(GateEntryController.BASE_PATH)
@RequiredArgsConstructor
public class GateEntryController implements GateEntryApi {

    static final String BASE_PATH = "/api/v1/gates";

    private final GateEntryService gateEntryService;

    @Override
    public ResponseEntity<GateEntryVerifyResponseDto> verify(GateEntryVerifyRequestDto request) {
        return ResponseEntity.ok(gateEntryService.verify(request));
    }
}
