package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 등록가가 정가를 넘은 경우. 화면이 상한을 바로 보여 줄 수 있게 두 값을 싣는다.
 *
 * <p>기준은 현재 구역 가격이 아니라 예매 시점 정가 스냅샷({@code ticket.face_value}) 이다.
 * 구역 가격이 나중에 바뀌어도 그 티켓의 기준은 예매 당시 정가여야 한다.
 */
public class ListPriceExceedsFacePriceException extends BusinessException {

    public ListPriceExceedsFacePriceException(int price, int faceValue) {
        super(TransferErrorCode.LIST_PRICE_EXCEEDS_FACE_PRICE,
                TransferErrorCode.LIST_PRICE_EXCEEDS_FACE_PRICE.getMessage()
                        + " (price=" + price + ", faceValue=" + faceValue + ")");
    }
}
