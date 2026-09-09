package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.security.exception.AuthErrorCode;
import com.ssafy.timo.global.security.exception.AuthException;

/** 탈퇴한 계정의 로그인 시도. 탈퇴는 행 삭제가 아니라 상태라 대조 자체는 통과한다. */
public class MemberWithdrawnException extends AuthException {

    public MemberWithdrawnException() {
        super(AuthErrorCode.MEMBER_WITHDRAWN);
    }
}
