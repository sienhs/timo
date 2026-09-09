package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.security.exception.AuthErrorCode;
import com.ssafy.timo.global.security.exception.AuthException;

/** 정지된 계정의 로그인 시도. 비밀번호를 맞힌 뒤에 걸리므로 사유를 그대로 알려준다. */
public class MemberSuspendedException extends AuthException {

    public MemberSuspendedException() {
        super(AuthErrorCode.MEMBER_SUSPENDED);
    }
}
