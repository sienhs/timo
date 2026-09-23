package com.ssafy.timo.domain.captcha.controller;

import com.ssafy.timo.domain.captcha.dto.CaptchaIssueResponseDto;
import com.ssafy.timo.domain.captcha.dto.CaptchaVerifyRequestDto;
import com.ssafy.timo.domain.captcha.dto.CaptchaVerifyResponseDto;
import com.ssafy.timo.domain.captcha.service.CaptchaService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 캡차 API. 규약과 매핑은 {@link CaptchaApi} 에 있다. */
@RestController
@RequestMapping(CaptchaController.BASE_PATH)
@RequiredArgsConstructor
public class CaptchaController implements CaptchaApi {

    static final String BASE_PATH = "/api/v1/captcha";

    private final CaptchaService captchaService;

    @Override
    public ResponseEntity<CaptchaIssueResponseDto> issue(Long memberId) {
        return ResponseEntity.ok(captchaService.issue(memberId));
    }

    @Override
    public ResponseEntity<CaptchaVerifyResponseDto> verify(Long memberId, CaptchaVerifyRequestDto request) {
        return ResponseEntity.ok(captchaService.verify(memberId, request));
    }
}
