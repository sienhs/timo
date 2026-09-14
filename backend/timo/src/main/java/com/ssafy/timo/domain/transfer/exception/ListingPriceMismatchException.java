package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 구매자가 보낸 {@code expectedPrice} 가 서버의 등록가와 다른 경우.
 *
 * <p>등록가는 등록 후 바뀌지 않지만, 목록을 받아 둔 화면과 구매 요청 사이에 시차가 있어
 * 앱이 옛 가격을 들고 있을 수 있다. 사용자가 본 금액과 다른 금액이 빠져나가지 않게 막는다.
 *
 * <p>메시지에 실제 가격을 담지 않는다. 남의 매물 가격을 확인하는 경로가 되면 안 된다.
 */
public class ListingPriceMismatchException extends BusinessException {

    public ListingPriceMismatchException(Long listingId) {
        super(TransferErrorCode.LISTING_PRICE_MISMATCH,
                TransferErrorCode.LISTING_PRICE_MISMATCH.getMessage() + " (listingId=" + listingId + ")");
    }
}
