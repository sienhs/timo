package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 없는 거래이거나 요청자가 판매자도 구매자도 아닌 거래를 조회한 경우. 응답은 둘 다 404 다. */
public class TradeNotFoundException extends BusinessException {

    public TradeNotFoundException(Long tradeId) {
        super(TransferErrorCode.TRADE_NOT_FOUND,
                TransferErrorCode.TRADE_NOT_FOUND.getMessage() + " (tradeId=" + tradeId + ")");
    }
}
