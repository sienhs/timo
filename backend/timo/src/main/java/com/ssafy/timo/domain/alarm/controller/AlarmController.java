package com.ssafy.timo.domain.alarm.controller;

import com.ssafy.timo.domain.alarm.dto.AlarmListRequestDto;
import com.ssafy.timo.domain.alarm.dto.AlarmStatusResponseDto;
import com.ssafy.timo.domain.alarm.entity.AlarmType;
import com.ssafy.timo.domain.alarm.service.AlarmService;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 공연 알림 신청 API (v1). 규약은 {@link AlarmApi} 에 있다.
 *
 * <p>모든 경로가 인증을 요구한다. {@code SecurityConfig} 의 {@code anyRequest().authenticated()} 가
 * 받으므로 경로를 따로 등록하지 않는다.
 */
@RestController
@RequestMapping("/api/v1/alarms")
@RequiredArgsConstructor
public class AlarmController implements AlarmApi {

    private final AlarmService alarmService;

    @Override
    public ResponseEntity<Void> add(Long concertId, AlarmType type, Long memberId) {
        alarmService.add(memberId, concertId, type);
        return ResponseEntity.noContent().build();
    }

    @Override
    public ResponseEntity<Void> remove(Long concertId, AlarmType type, Long memberId) {
        alarmService.remove(memberId, concertId, type);
        return ResponseEntity.noContent().build();
    }

    @Override
    public ResponseEntity<AlarmStatusResponseDto> findStatus(Long concertId, Long memberId) {
        return ResponseEntity.ok(alarmService.findStatus(memberId, concertId));
    }

    @Override
    public ResponseEntity<PagedModel<ConcertSummaryResponseDto>> findMine(AlarmListRequestDto request, Long memberId) {
        return ResponseEntity.ok(alarmService.findMine(memberId, request));
    }
}
