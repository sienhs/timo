package com.ssafy.timo.domain.ticket.controller;

import com.ssafy.timo.domain.ticket.dto.EntryPassResponseDto;
import com.ssafy.timo.domain.ticket.service.EntryPassService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 입장 QR API (v1, 실제 구현).
 *
 * <p>엔드포인트 규약은 {@link EntryPassApi} 에 있다. 이 클래스는 버전 경로를 정하고 서비스에
 * 위임만 한다. 프론트 연동용 v0 스텁은 두지 않는다 - 팬 앱이 이미 자체 생성한 문자열로 화면을
 * 띄우고 있어, 스텁을 하나 더 만드는 대신 이 엔드포인트로 바로 갈아타면 된다.
 *
 * <p>요청자는 {@link com.ssafy.timo.global.security.CurrentMember} 가 알려 준다. 토큰이 없으면
 * 401 로 끊는 일은 그 리졸버가 하므로 여기서는 받은 값을 넘기기만 한다.
 */
@RestController
@RequestMapping(EntryPassController.BASE_PATH)
@RequiredArgsConstructor
public class EntryPassController implements EntryPassApi {

    static final String BASE_PATH = "/api/v1/tickets";

    private final EntryPassService entryPassService;

    @Override
    public ResponseEntity<EntryPassResponseDto> issueEntryPass(Long ticketId, Long memberId) {
        return ResponseEntity.ok(entryPassService.issue(memberId, ticketId));
    }
}
