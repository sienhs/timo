package com.ssafy.timo.domain.auth.controller;

import com.ssafy.timo.domain.auth.dto.SmsSendRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsSendResponseDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyResponseDto;
import com.ssafy.timo.domain.auth.service.SmsVerificationService; // 동일 구조 FQN 참조
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping(AuthController.BASE_PATH)
@RequiredArgsConstructor
public class AuthController {

    static final String BASE_PATH = "/api/v1/auth";

    private final SmsVerificationService smsVerificationService;

    @PostMapping("/sms/send")
    public ResponseEntity<SmsSendResponseDto> sendSmsCode(@Valid @RequestBody SmsSendRequestDto request,
                                                          HttpServletRequest httpRequest) {
        return ResponseEntity.ok(smsVerificationService.sendCode(request, httpRequest.getRemoteAddr()));
    }

    @PostMapping("/sms/verify")
    public ResponseEntity<SmsVerifyResponseDto> verifySmsCode(@Valid @RequestBody SmsVerifyRequestDto request) {
        return ResponseEntity.ok(smsVerificationService.verifyCode(request));
    }
}
