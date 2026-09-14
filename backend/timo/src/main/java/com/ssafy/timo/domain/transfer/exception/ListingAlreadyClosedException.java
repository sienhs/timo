package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 이미 팔렸거나 취소된 매물을 사거나 취소하려 한 경우.
 *
 * <p>조건부 UPDATE 의 영향 행이 0 이면 이 예외를 던진다. 조회해서 상태를 확인한 뒤 UPDATE 하면
 * 두 요청이 같은 매물을 동시에 통과하므로, 상태 판정은 UPDATE 의 결과로만 한다.
 */
public class ListingAlreadyClosedException extends BusinessException {

    public ListingAlreadyClosedException(Long listingId) {
        super(TransferErrorCode.LISTING_ALREADY_CLOSED,
                TransferErrorCode.LISTING_ALREADY_CLOSED.getMessage() + " (listingId=" + listingId + ")");
    }
}
