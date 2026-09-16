package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 체결 시점 정가 재검증에서 등록가가 정가를 넘은 경우.
 *
 * <p>등록 시에도 같은 검증을 하고 {@code face_value} 는 등록 시점 스냅샷이라 불변이므로,
 * 정상 경로에서는 도달하지 않는다. 데이터가 손상됐을 때만 걸리는 방어선이다.
 *
 * <p>등록 시의 {@link ListPriceExceedsFacePriceException}(400) 과 코드를 나눈 이유는
 * {@link TransferErrorCode} 주석을 본다.
 */
public class TradePriceExceedsFaceValueException extends BusinessException {

    public TradePriceExceedsFaceValueException(Long listingId) {
        super(TransferErrorCode.TRADE_PRICE_EXCEEDS_FACE_VALUE,
                TransferErrorCode.TRADE_PRICE_EXCEEDS_FACE_VALUE.getMessage() + " (listingId=" + listingId + ")");
    }
}
