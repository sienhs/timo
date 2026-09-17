package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 등록가가 정가를 넘은 경우. 화면이 상한을 바로 보여 줄 수 있게 두 값을 싣는다.
 *
 * <p>기준은 공연 전체 단일가가 아니라 그 좌석이 속한 구역의 가격({@code Section.price}) 이다.
 * 예매 결제와 환불이 모두 그 값으로 이루어지므로 재판매 상한도 같은 기준이어야 한다. 등록된 매물은
 * 등록 시점의 값을 {@code ticket_listing.face_value} 에 스냅샷으로 들고 있다.
 */
public class ListPriceExceedsFacePriceException extends BusinessException {

    public ListPriceExceedsFacePriceException(long price, long faceValue) {
        super(TransferErrorCode.LIST_PRICE_EXCEEDS_FACE_PRICE,
                TransferErrorCode.LIST_PRICE_EXCEEDS_FACE_PRICE.getMessage()
                        + " (price=" + price + ", faceValue=" + faceValue + ")");
    }
}
