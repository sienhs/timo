package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 등록가가 온체인 정가보다 큰 경우. 화면이 상한을 바로 보여 줄 수 있게 두 값을 싣는다. */
public class ListPriceExceedsFacePriceException extends BusinessException {

    public ListPriceExceedsFacePriceException(long askPrice, long facePrice) {
        super(TransferErrorCode.LIST_PRICE_EXCEEDS_FACE_PRICE,
                TransferErrorCode.LIST_PRICE_EXCEEDS_FACE_PRICE.getMessage()
                        + " (askPrice=" + askPrice + ", facePrice=" + facePrice + ")");
    }
}
