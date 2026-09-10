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
import com.ssafy.timo.domain.auth.exception.SmsCodeMismatchException;
import com.ssafy.timo.domain.auth.exception.VerificationTicketInvalidException;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.annotation.Profile;
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

/**
 * 프론트 연동용 스텁. DB 도 서비스도 타지 않고 <b>고정된 값만</b> 돌려준다.
 *
 * <p>경로와 응답 스키마는 {@link AuthController} 와 같고 버전만 {@code v0} 이다. 프론트는
 * base URL 의 {@code v0} 을 {@code v1} 로 바꾸는 것만으로 실제 API 로 넘어갈 수 있다.
 *
 * <p>요청 DTO 와 검증을 v1 과 <b>같은 것을 쓴다.</b> 스텁이라고 검증을 빼면 프론트가 400 응답
 * 처리를 못 만들어 보고, 실제 API 로 바꾸는 순간 처음 보는 에러를 만나게 된다.
 *
 * <p><b>{@code prod} 에서는 뜨지 않는다.</b> 비밀번호를 확인하지 않고 토큰을 내주는 엔드포인트라
 * 운영에 올라가면 그대로 인증 우회다. 발급하는 토큰도 서명된 JWT 가 아닌 고정 문자열이라
 * v1 엔드포인트에는 통하지 않는다.
 *
 * <p>실패 분기를 볼 수 있도록 트리거를 정해 뒀다. 성공만 돌려주면 프론트가 오류 화면을
 * 만들어 볼 수가 없다.
 *
 * <table border="1">
 *   <caption>실패 트리거</caption>
 *   <tr><td>{@code /sms/verify}</td><td>인증번호가 {@code 000000} 이 아니면 실패</td></tr>
 *   <tr><td>{@code /availability}</td><td>값이 {@code taken} 으로 시작하면 사용 중</td></tr>
 *   <tr><td>{@code /signup}</td><td>티켓이 {@link #TICKET} 이 아니면 실패</td></tr>
 *   <tr><td>{@code /login}</td><td>{@code timo_user} / {@code timo1234!} 만 성공</td></tr>
 *   <tr><td>{@code /reissue}</td><td>{@link #REFRESH_TOKEN} 이 아니면 실패</td></tr>
 * </table>
 */
@Slf4j
@RestController
@RequestMapping(AuthControllerStub.BASE_PATH)
@Profile("!prod")
public class AuthControllerStub {

    static final String BASE_PATH = "/api/v0/auth";

    private static final String DEVICE_ID_HEADER = "X-Device-Id";

    /** 서명된 JWT 가 아니다. v1 에 제출하면 통과하지 못한다. */
    private static final String ACCESS_TOKEN = "stub-access-token";
    private static final String REFRESH_TOKEN = "stub-refresh-token";
    private static final String TICKET = "stub-verification-ticket";

    private static final long MEMBER_ID = 1L;
    private static final long ACCESS_TOKEN_EXPIRES_IN = 1800L;
    private static final int CODE_EXPIRES_IN = 180;
    private static final int TICKET_EXPIRES_IN = 1800;

    private static final String VALID_CODE = "000000";
    private static final String TAKEN_PREFIX = "taken";

    @PostMapping("/sms/send")
    public ResponseEntity<SmsSendResponseDto> sendSmsCode(@Valid @RequestBody SmsSendRequestDto request) {
        log.info("[stub] sms send: phoneNumber={}", request.phoneNumber());
        return ResponseEntity.ok(new SmsSendResponseDto(CODE_EXPIRES_IN));
    }

    @PostMapping("/sms/verify")
    public ResponseEntity<SmsVerifyResponseDto> verifySmsCode(@Valid @RequestBody SmsVerifyRequestDto request) {
        if (!VALID_CODE.equals(request.code())) {
            throw new SmsCodeMismatchException();
        }
        return ResponseEntity.ok(new SmsVerifyResponseDto(TICKET, TICKET_EXPIRES_IN));
    }

    @GetMapping("/availability")
    public ResponseEntity<AvailabilityResponseDto> checkAvailability(
            @Valid @ModelAttribute AvailabilityRequestDto request) {

        String value = request.isUsernameCheck() ? request.username() : request.nickname();

        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .body(new AvailabilityResponseDto(!value.startsWith(TAKEN_PREFIX)));
    }

    @PostMapping("/signup")
    public ResponseEntity<SignupResponseDto> signUp(
            @Valid @RequestBody SignupRequestDto request,
            @RequestHeader(DEVICE_ID_HEADER)
            @NotBlank(message = "기기 식별자가 필요합니다.")
            @Size(max = 64, message = "기기 식별자가 너무 깁니다.") String deviceId) {

        if (!TICKET.equals(request.verificationTicket())) {
            throw new VerificationTicketInvalidException();
        }

        return ResponseEntity.status(HttpStatus.CREATED).body(new SignupResponseDto(
                MEMBER_ID, ACCESS_TOKEN, REFRESH_TOKEN, ACCESS_TOKEN_EXPIRES_IN));
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponseDto> login(
            @Valid @RequestBody LoginRequestDto request,
            BindingResult bindingResult,
            @RequestHeader(DEVICE_ID_HEADER)
            @NotBlank(message = "기기 식별자가 필요합니다.")
            @Size(max = 64, message = "기기 식별자가 너무 깁니다.") String deviceId) {

        return ResponseEntity.ok(new LoginResponseDto(
                MEMBER_ID, ACCESS_TOKEN, REFRESH_TOKEN, ACCESS_TOKEN_EXPIRES_IN));
    }

    @PostMapping("/reissue")
    public ResponseEntity<ReissueResponseDto> reissue(
            @Valid @RequestBody RefreshTokenRequestDto request,
            BindingResult bindingResult,
            @RequestHeader(DEVICE_ID_HEADER)
            @NotBlank(message = "기기 식별자가 필요합니다.")
            @Size(max = 64, message = "기기 식별자가 너무 깁니다.") String deviceId) {

        if (bindingResult.hasErrors() || !REFRESH_TOKEN.equals(request.refreshToken())) {
            throw new TokenInvalidException();
        }

        return ResponseEntity.ok(new ReissueResponseDto(ACCESS_TOKEN, ACCESS_TOKEN_EXPIRES_IN));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(
            @Valid @RequestBody RefreshTokenRequestDto request,
            BindingResult bindingResult,
            @RequestHeader(DEVICE_ID_HEADER)
            @NotBlank(message = "기기 식별자가 필요합니다.")
            @Size(max = 64, message = "기기 식별자가 너무 깁니다.") String deviceId) {

        // v1 과 마찬가지로 멱등하다. 끊을 세션이 없어도 성공이다.
        return ResponseEntity.noContent().build();
    }
}
