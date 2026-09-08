package com.ssafy.timo.domain.auth.exception;

import com.ssafy.timo.global.exception.BusinessException;

public class VerificationTicketInvalidException extends BusinessException {

    public VerificationTicketInvalidException() {
        super(SignupErrorCode.VERIFICATION_TICKET_INVALID);
    }
}
