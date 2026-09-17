package com.ssafy.timo.domain.notification.controller;

import com.ssafy.timo.domain.notification.dto.PushDeviceRegistrationRequest;
import com.ssafy.timo.domain.notification.dto.PushDeviceUnregistrationRequest;
import com.ssafy.timo.domain.notification.service.PushDeviceService;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 앱이 FCM 토큰을 회원 계정에 등록·해제하는 인증된 API. */
@RestController
@RequestMapping("/api/v1/notifications/devices")
@RequiredArgsConstructor
public class PushDeviceController {

    private final PushDeviceService pushDeviceService;

    @PutMapping
    public ResponseEntity<Void> register(@CurrentMember Long memberId,
                                         @Valid @RequestBody PushDeviceRegistrationRequest request) {
        pushDeviceService.register(memberId, request);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping
    public ResponseEntity<Void> unregister(@CurrentMember Long memberId,
                                           @Valid @RequestBody PushDeviceUnregistrationRequest request) {
        pushDeviceService.unregister(memberId, request.token());
        return ResponseEntity.noContent().build();
    }
}
