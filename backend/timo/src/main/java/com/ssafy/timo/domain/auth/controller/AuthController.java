package com.ssafy.timo.domain.auth.controller;

import com.ssafy.timo.domain.auth.dto.AvailabilityRequestDto;
import com.ssafy.timo.domain.auth.dto.AvailabilityResponseDto;
import com.ssafy.timo.domain.auth.dto.LoginRequestDto;
import com.ssafy.timo.domain.auth.dto.LoginResponseDto;
import com.ssafy.timo.domain.auth.dto.RefreshTokenRequestDto;
import com.ssafy.timo.domain.auth.dto.ReissueResponseDto;
import com.ssafy.timo.domain.auth.dto.SignupRequestDto;
import com.ssafy.timo.domain.auth.dto.SignupResponseDto;
import com.ssafy.timo.domain.auth.dto.SmsSendRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsSendResponseDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyRequestDto;
import com.ssafy.timo.domain.auth.dto.SmsVerifyResponseDto;
import com.ssafy.timo.domain.auth.exception.LoginFailedException;
import com.ssafy.timo.domain.auth.service.AvailabilityService;
import com.ssafy.timo.domain.auth.service.LoginService;
import com.ssafy.timo.domain.auth.service.LogoutService;
import com.ssafy.timo.domain.auth.service.SignupService;
import com.ssafy.timo.domain.auth.service.SmsVerificationService; // 동일 구조 FQN 참조
import com.ssafy.timo.domain.auth.service.TokenReissueService;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
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
    private final TokenReissueService tokenReissueService;
    private final LogoutService logoutService;

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
     * access 토큰 재발급. refresh 는 회전시키지 않으므로 응답에 없다.
     *
     * <p>인증을 걸지 않는다. 이걸 부르는 시점은 access 가 <b>이미 만료된</b> 때라, 인증을 요구하면
     * 재발급받으려면 재발급이 필요한 순환에 빠진다. 본문의 refresh 토큰 자체가 인증 수단이다.
     */
    @PostMapping("/reissue")
    public ResponseEntity<ReissueResponseDto> reissue(
            @Valid @RequestBody RefreshTokenRequestDto request,
            BindingResult bindingResult,
            @RequestHeader(DEVICE_ID_HEADER)
            @NotBlank(message = "기기 식별자가 필요합니다.")
            @Size(max = 64, message = "기기 식별자가 너무 깁니다.") String deviceId) {

        // 검증 실패도 토큰 문제와 같은 401 TOKEN_INVALID 로 내보낸다. 400 으로 나가면 errorCode 가
        // 없어서, 앱이 "로그인 화면으로 보내라" 는 신호를 못 받고 재발급 루프에 남는다.
        if (bindingResult.hasErrors()) {
            log.warn("Reissue rejected by request validation: deviceId={}, errors={}",
                    deviceId, bindingResult.getAllErrors());
            throw new TokenInvalidException();
        }

        return ResponseEntity.ok(tokenReissueService.reissue(request.refreshToken(), deviceId));
    }

    /**
     * 그 기기의 세션을 끊는다. 이미 끊겨 있어도 성공이다.
     *
     * <p>재발급과 같은 이유로 인증을 걸지 않는다. 남의 refresh 토큰을 안다면 이미 그 세션을 쓸 수
     * 있으므로, 로그아웃시키는 것이 추가 피해가 되지 않는다.
     */
    @PostMapping("/logout")
    public ResponseEntity<Void> logout(
            @Valid @RequestBody RefreshTokenRequestDto request,
            BindingResult bindingResult,
            @RequestHeader(DEVICE_ID_HEADER)
            @NotBlank(message = "기기 식별자가 필요합니다.")
            @Size(max = 64, message = "기기 식별자가 너무 깁니다.") String deviceId) {

        // 로그아웃은 실패할 이유가 없다. 값이 비어 있으면 끊을 세션이 없다는 뜻이고,
        // 그건 이미 원하는 상태다. 앱을 로그아웃 화면에 붙잡아 둘 이유가 없다.
        if (!bindingResult.hasErrors()) {
            logoutService.logout(request.refreshToken(), deviceId);
        }

        return ResponseEntity.noContent().build();
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
