package com.ssafy.timo.domain.wallet.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

@Getter
@RequiredArgsConstructor
public enum WalletErrorCode implements BaseErrorCode {

    /** 온체인 충전 반영이 실패했다. 사용자 잘못이 아니라 재시도 대상. */
    WALLET_CHARGE_FAILED(HttpStatus.SERVICE_UNAVAILABLE, "충전 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.");

    private final HttpStatus status;
    private final String message;
}
