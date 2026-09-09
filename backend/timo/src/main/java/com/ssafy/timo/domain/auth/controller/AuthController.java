package com.ssafy.timo.domain.auth.controller;

import com.ssafy.timo.domain.auth.dto.AvailabilityRequestDto;
import com.ssafy.timo.domain.auth.dto.AvailabilityResponseDto;
import com.ssafy.timo.domain.auth.dto.LoginRequestDto;
import com.ssafy.timo.domain.auth.dto.LoginResponseDto;
import com.ssafy.timo.domain.auth.dto.SignupRequestDto;
import com.ssafy.timo.domain.auth.dto.SignupResponseDto;
import com.ssafy.timo.domain.auth.dto.SmsSendRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsSendResponseDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyResponseDto;
import com.ssafy.timo.domain.auth.exception.LoginFailedException;
import com.ssafy.timo.domain.auth.service.AvailabilityService;
import com.ssafy.timo.domain.auth.service.LoginService;
import com.ssafy.timo.domain.auth.service.SignupService;
import com.ssafy.timo.domain.auth.service.SmsVerificationService; // 동일 구조 FQN 참조
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.BindingResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
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
    private final LoginService loginService;
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
     * 아이디·비밀번호 로그인. 성공하면 가입과 같은 모양으로 토큰을 내려준다.
     *
     * <p>{@code X-Device-Id} 가 가입과 같아야 하는 이유가 있다. refresh 토큰은
     * {@code (member_id, device_id)} 로 유일해서, 기기 식별자가 갈리면 같은 폰에
     * 세션이 둘 생겨 폰을 잃어버렸을 때 한쪽이 끊기지 않고 남는다.
     *
     * <p>가입과 달리 201 이 아니라 200 이다. 로그인은 회원을 만들지 않는다. 세션 행은 같은 기기면
     * 새로 만들지 않고 갱신하므로, 201 로 두면 같은 요청이 첫 로그인이냐 재로그인이냐에 따라
     * "생성했다" 와 "안 했다" 를 오간다.
     */
    @PostMapping("/login")
    public ResponseEntity<LoginResponseDto> login(
            @Valid @RequestBody LoginRequestDto request,
            BindingResult bindingResult,
            @RequestHeader(DEVICE_ID_HEADER)
            @NotBlank(message = "기기 식별자가 필요합니다.")
            @Size(max = 64, message = "기기 식별자가 너무 깁니다.") String deviceId) {

        // BindingResult 를 받으면 스프링이 예외를 던지지 않고 결과를 넘겨준다. 그래야 검증 실패를
        // 여기서 흡수할 수 있다. 그냥 두면 errorCode 없는 검증 실패 응답이 나가 로그인 실패가
        // 두 모양이 되고, 어느 조건에 걸렸는지가 그대로 밖에 드러난다.
        //
        // 사유는 로그로만 남긴다. 개발 중 오탈자를 추적할 수단은 있어야 하는데,
        // 그걸 응답에 실으면 밖에서도 같은 것을 알게 된다.
        if (bindingResult.hasErrors()) {
            log.warn("Login rejected by request validation: deviceId={}, errors={}",
                    deviceId, bindingResult.getAllErrors());
            throw new LoginFailedException();
        }

        return ResponseEntity.ok(loginService.login(request, deviceId));
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
