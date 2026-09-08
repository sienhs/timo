package com.ssafy.timo.domain.auth.controller;

import com.ssafy.timo.domain.auth.dto.AvailabilityRequestDto;
import com.ssafy.timo.domain.auth.dto.AvailabilityResponseDto;
import com.ssafy.timo.domain.auth.dto.SignupRequestDto;
import com.ssafy.timo.domain.auth.dto.SignupResponseDto;
import com.ssafy.timo.domain.auth.dto.SmsSendRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsSendResponseDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyResponseDto;
import com.ssafy.timo.domain.auth.service.AvailabilityService;
import com.ssafy.timo.domain.auth.service.SignupService;
import com.ssafy.timo.domain.auth.service.SmsVerificationService; // 동일 구조 FQN 참조
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Validated
@RestController
@RequestMapping(AuthController.BASE_PATH)
@RequiredArgsConstructor
public class AuthController {

    static final String BASE_PATH = "/api/v1/auth";

    /**
     * 클라이언트가 만들어 기기에 보관하는 UUID.
     *
     * <p>기기별로 세션을 관리하려면 필요하다. 없으면 폰을 잃어버렸을 때 그 기기만 끊을 수 없다.
     */
    private static final String DEVICE_ID_HEADER = "X-Device-Id";

    private final SmsVerificationService smsVerificationService;
    private final SignupService signupService;
    private final AvailabilityService availabilityService;

    @PostMapping("/sms/send")
    public ResponseEntity<SmsSendResponseDto> sendSmsCode(@Valid @RequestBody SmsSendRequestDto request,
                                                          HttpServletRequest httpRequest) {
        return ResponseEntity.ok(smsVerificationService.sendCode(request, httpRequest.getRemoteAddr()));
    }

    @PostMapping("/sms/verify")
    public ResponseEntity<SmsVerifyResponseDto> verifySmsCode(@Valid @RequestBody SmsVerifyRequestDto request) {
        return ResponseEntity.ok(smsVerificationService.verifyCode(request));
    }

    /** 가입과 동시에 로그인 상태가 되도록 토큰까지 함께 내려준다. */
    @PostMapping("/signup")
    public ResponseEntity<SignupResponseDto> signUp(
            @Valid @RequestBody SignupRequestDto request,
            @RequestHeader(DEVICE_ID_HEADER)
            @NotBlank(message = "기기 식별자가 필요합니다.")
            @Size(max = 64, message = "기기 식별자가 너무 깁니다.") String deviceId) {

        return ResponseEntity.status(HttpStatus.CREATED).body(signupService.signUp(request, deviceId));
    }

    /**
     * 아이디·닉네임 중복 확인. 둘 중 하나만 쿼리 파라미터로 보낸다.
     *
     * <pre>
     * GET /api/v1/auth/availability?username=timo
     * GET /api/v1/auth/availability?nickname=티모
     * </pre>
     *
     * <p>{@code no-store} 를 붙이는 이유가 있다. 안 붙이면 프록시가 "사용 가능" 을 캐싱해,
     * 이미 남이 채간 아이디를 계속 쓸 수 있다고 답한다.
     */
    @GetMapping("/availability")
    public ResponseEntity<AvailabilityResponseDto> checkAvailability(
            @Valid @ModelAttribute AvailabilityRequestDto request) {

        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .body(availabilityService.check(request));
    }
}
