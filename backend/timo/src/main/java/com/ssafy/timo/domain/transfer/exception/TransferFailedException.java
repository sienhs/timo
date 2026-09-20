package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 온체인 체결이 실패했을 때. 원인(revert·일시적 오류)은 사용자에게 알릴 이유가 없는 내부 값이라
 * 로그로만 남긴다({@code PurchaseService}).
 */
public class TransferFailedException extends BusinessException {

    public TransferFailedException(Long listingId) {
        super(TransferErrorCode.TRANSFER_FAILED,
                TransferErrorCode.TRANSFER_FAILED.getMessage() + " (listingId=" + listingId + ")");
    }
}
