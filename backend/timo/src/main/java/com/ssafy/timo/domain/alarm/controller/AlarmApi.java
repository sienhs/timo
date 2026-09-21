package com.ssafy.timo.domain.alarm.controller;

import com.ssafy.timo.domain.alarm.dto.AlarmListRequestDto;
import com.ssafy.timo.domain.alarm.dto.AlarmStatusResponseDto;
import com.ssafy.timo.domain.alarm.entity.AlarmType;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;

/**
 * 공연 알림 신청 API 규약.
 *
 * <p>알림 신청은 회원의 것이라 요청자를 {@link CurrentMember} 로만 받는다. 신청과 해제는 공연 식별자와
 * 알림 종류({@link AlarmType}) 를 경로로 받고 본문이 없으며, <b>둘 다 멱등이라 204</b> 다 — 이미 신청한
 * 알림을 다시 신청해도, 신청하지 않은 알림을 풀어도 같은 응답이다.
 *
 * <p>종류는 {@code CONCERT_OPEN}(예매 오픈 안내) 과 {@code MARKET_LISTING}(양도 매물 안내) 이다. 종류마다
 * 따로 신청하고 따로 풀며, 한 종류를 풀어도 같은 공연의 다른 종류는 그대로다. 없는 종류 값은 400 이다.
 *
 * <p>알림 신청은 찜과 별개다. 찜을 하거나 풀어도 알림 신청은 바뀌지 않는다.
 */
public interface AlarmApi {

    /** 알림을 신청한다. 없는 공연이면 404, 이미 신청했으면 그대로 204. */
    @PutMapping("/{concertId}/{type}")
    ResponseEntity<Void> add(
            @PathVariable Long concertId,
            @PathVariable AlarmType type,
            @CurrentMember Long memberId);

    /** 알림 신청을 푼다. 신청하지 않았어도 204. */
    @DeleteMapping("/{concertId}/{type}")
    ResponseEntity<Void> remove(
            @PathVariable Long concertId,
            @PathVariable AlarmType type,
            @CurrentMember Long memberId);

    /**
     * 이 공연에 대한 내 알림 신청 상태. 종류마다 신청했는지를 {@code true}/{@code false} 로 준다.
     *
     * <p>공연 상세는 로그인 없이 열려 있어 요청자별 값을 실을 수 없다. 상세 화면의 알림 버튼은 이 응답으로 켜짐과
     * 꺼짐을 그린다. 없는 공연이어도 404 가 아니라 둘 다 {@code false} 다.
     */
    @GetMapping("/{concertId}")
    ResponseEntity<AlarmStatusResponseDto> findStatus(@PathVariable Long concertId, @CurrentMember Long memberId);

    /** 내가 이 종류의 알림을 신청한 공연 목록. {@code type} 은 필수이고, 최근 신청한 순이며 공연 목록과 같은 요약 모양이다. */
    @GetMapping("/me")
    ResponseEntity<PagedModel<ConcertSummaryResponseDto>> findMine(
            @Valid @ModelAttribute AlarmListRequestDto request,
            @CurrentMember Long memberId);
}
