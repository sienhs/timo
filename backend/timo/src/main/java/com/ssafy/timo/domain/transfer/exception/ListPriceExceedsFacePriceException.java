package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 등록가가 정가를 넘은 경우. 화면이 상한을 바로 보여 줄 수 있게 두 값을 싣는다.
 *
 * <p>기준은 구역 가격이 아니라 공연 정가({@code Concert.facePrice}) 다. 예매 결제·환불이 모두
 * 그 값으로 이루어지므로 정가도 그 값이어야 한다. 등록된 매물은 등록 시점의 값을
 * {@code ticket_listing.face_value} 에 스냅샷으로 들고 있다.
 */
public class ListPriceExceedsFacePriceException extends BusinessException {

    public ListPriceExceedsFacePriceException(long price, long faceValue) {
        super(TransferErrorCode.LIST_PRICE_EXCEEDS_FACE_PRICE,
                TransferErrorCode.LIST_PRICE_EXCEEDS_FACE_PRICE.getMessage()
                        + " (price=" + price + ", faceValue=" + faceValue + ")");
    }
}
