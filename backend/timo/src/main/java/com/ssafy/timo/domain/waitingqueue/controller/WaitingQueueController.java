package com.ssafy.timo.domain.waitingqueue.controller;

import com.ssafy.timo.domain.waitingqueue.dto.WaitingQueueResponseDto;
import com.ssafy.timo.domain.waitingqueue.service.WaitingQueueService;
import com.ssafy.timo.global.security.CurrentMember;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/concerts/{concertId}/queue")
@RequiredArgsConstructor
public class WaitingQueueController {
    private final WaitingQueueService waitingQueueService;
    @PostMapping public ResponseEntity<WaitingQueueResponseDto> join(@PathVariable Long concertId, @CurrentMember Long memberId) { return ResponseEntity.ok(waitingQueueService.join(concertId, memberId)); }
    @GetMapping public ResponseEntity<WaitingQueueResponseDto> status(@PathVariable Long concertId, @CurrentMember Long memberId) { return ResponseEntity.ok(waitingQueueService.status(concertId, memberId)); }
    @DeleteMapping public ResponseEntity<Void> leave(@PathVariable Long concertId, @CurrentMember Long memberId) { waitingQueueService.leave(concertId, memberId); return ResponseEntity.noContent().build(); }
}
