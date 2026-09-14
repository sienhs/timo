package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 자기 매물을 자기가 사려 한 경우.
 *
 * <p>온체인에서는 1인 1매({@code AlreadyHoldsShowTicket})에 먼저 걸리지만, 화면에 보여 줄 말이 달라 따로 둔다.
 */
public class CannotBuyOwnListingException extends BusinessException {

    public CannotBuyOwnListingException(Long listingId) {
        super(TransferErrorCode.CANNOT_BUY_OWN_LISTING,
                TransferErrorCode.CANNOT_BUY_OWN_LISTING.getMessage() + " (listingId=" + listingId + ")");
    }
}
