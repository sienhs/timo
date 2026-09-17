package com.ssafy.timo.domain.ticket.controller;

import com.ssafy.timo.domain.ticket.dto.EntryPassResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

/**
 * 입장 QR API 규약.
 *
 * <p>매핑과 검증 애노테이션은 여기에만 둔다. 구현체는 클래스 레벨 {@code @RequestMapping} 으로
 * 버전 경로만 정한다. 자세한 이유는 {@link com.ssafy.timo.domain.venue.controller.VenueApi} 참고.
 */
public interface EntryPassApi {

    /**
     * 내 티켓의 입장 QR 을 발급한다.
     *
     * <p>수명이 짧아 앱은 만료 전에 계속 다시 부른다. 그래서 GET 이다 - 서버에 아무것도 남기지
     * 않고, 같은 티켓으로 몇 번을 불러도 상태가 달라지지 않는다. 매번 다른 문자열이 나오는 건
     * 만료 시각이 매번 달라서지 부수 효과가 있어서가 아니다.
     *
     * <p>내 티켓이 아니면 존재를 알리지 않고 404 다. 발행 전이거나 이미 입장했거나 회수된 티켓,
     * 입장 시간대 밖이면 409 다.
     */
    @GetMapping("/{ticketId}/entry-pass")
    ResponseEntity<EntryPassResponseDto> issueEntryPass(@PathVariable Long ticketId, @CurrentMember Long memberId);
}
