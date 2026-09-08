package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/**
 * 회원가입에서만 쓰는 에러 코드.
 *
 * <p>아이디는 {@code login_info}, 닉네임·전화번호는 {@code member} 에 있어 두 도메인에 걸쳐 있지만,
 * 이 값들이 함께 검사되는 곳은 가입 API 하나뿐이라 한 묶음으로 둔다.
 *
 * <p>티켓 만료를 401 이 아니라 400 으로 두는 이유가 있다. 가입은 인증 없이 부르는 API 라
 * 401 을 내보내면 앱의 "401 이면 토큰 재발급" 처리가 엉뚱하게 끼어든다. 만료된 인증번호를
 * {@link SmsErrorCode#SMS_CODE_NOT_FOUND} 로 400 처리하는 것과 같은 판단이다.
 */
@Getter
@RequiredArgsConstructor
public enum SignupErrorCode implements BaseErrorCode {

    VERIFICATION_TICKET_INVALID(HttpStatus.BAD_REQUEST, "본인인증이 만료되었습니다. 다시 인증해 주세요."),
    USERNAME_DUPLICATED(HttpStatus.CONFLICT, "이미 사용 중인 아이디입니다."),
    NICKNAME_DUPLICATED(HttpStatus.CONFLICT, "이미 사용 중인 닉네임입니다."),
    PHONE_NUMBER_DUPLICATED(HttpStatus.CONFLICT, "이미 가입된 전화번호입니다.");

    private final HttpStatus status;
    private final String message;
}
