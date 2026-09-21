package com.ssafy.timo.domain.wallet.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 충전 요청은 유효했지만 온체인 반영({@code TicketVault.deposit})이 실패한 경우.
 *
 * <p>{@code ContractCallException}의 상세는 사용자에게 알릴 이유가 없는 내부 값이라 메시지에
 * 담지 않는다. 호출부({@code WalletChargeService})가 원본 예외를 로그로 남긴다.
 */
public class WalletChargeFailedException extends BusinessException {

    public WalletChargeFailedException(Throwable cause) {
        super(WalletErrorCode.WALLET_CHARGE_FAILED);
        initCause(cause);
    }
}
