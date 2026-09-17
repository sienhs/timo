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
 * <p><b>ADMIN 역할만 호출할 수 있다.</b> {@code SecurityConfig} 가 이 경로를 {@code hasRole(ADMIN)}
 * 으로 제한한다 - QR 문자열을 아는 사람 누구나 호출할 수 있으면 캡처 한 장으로 관람객이 입구에
 * 서기도 전에 표가 소진된다. 게이트 앱은 아직 로그인 화면과 실제 API 연동이 없어(목으로만
 * 동작) 이 제한을 걸어도 지금 당장 깨지는 흐름은 없다 - 실제 연동을 붙일 때 로그인해 받은 토큰을
 * Authorization 헤더에 실어야 한다.
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
