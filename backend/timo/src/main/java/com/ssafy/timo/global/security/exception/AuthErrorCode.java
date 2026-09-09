package com.ssafy.timo.global.security.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum AuthErrorCode implements BaseErrorCode {

    TOKEN_EXPIRED(HttpStatus.UNAUTHORIZED, "인증이 만료되었습니다."),
    TOKEN_INVALID(HttpStatus.UNAUTHORIZED, "인증 정보가 올바르지 않습니다. 다시 로그인해 주세요."),
    REFRESH_REUSED(HttpStatus.UNAUTHORIZED, "보안을 위해 로그아웃되었습니다. 다시 로그인해 주세요."),

    /*
     * 로그인 실패를 401 이 아니라 400 으로 두는 이유가 있다. 로그인은 인증 없이 부르는 API 라
     * 401 을 내보내면 앱의 "401 이면 토큰 재발급" 처리가 엉뚱하게 끼어든다. 가입에서 티켓 만료를
     * SignupErrorCode.VERIFICATION_TICKET_INVALID 로 400 처리한 것과 같은 판단이다.
     * 덧붙여 RFC 9110 상 401 에는 WWW-Authenticate 헤더가 따라야 하는데, 컨트롤러에서 던지는
     * 예외는 그 헤더를 붙이지 않아 401 로 두면 규격에 맞지 않는 응답이 된다.
     *
     * 아이디가 없는 것과 비밀번호가 틀린 것을 구분하지 않는다. 구분해 주면 어떤 아이디가
     * 가입돼 있는지 밖에서 수집할 수 있다.
     */
    LOGIN_FAILED(HttpStatus.BAD_REQUEST, "아이디 또는 비밀번호가 올바르지 않습니다."),

    /*
     * 계정 상태 문제는 400 이 아니라 403 이다. 이 둘은 비밀번호를 맞힌 뒤에 걸리므로
     * "입력이 틀렸다" 가 아니고, 앱도 입력칸 오류가 아니라 별도 안내로 처리해야 한다.
     */
    MEMBER_SUSPENDED(HttpStatus.FORBIDDEN, "정지된 계정입니다. 고객센터로 문의해 주세요."),
    MEMBER_WITHDRAWN(HttpStatus.FORBIDDEN, "탈퇴한 계정입니다."),

    FORBIDDEN(HttpStatus.FORBIDDEN, "접근 권한이 없습니다.");

    private final HttpStatus status;
    private final String message;
}
