package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 존재하지 않는 매물을 조회·취소·구매하려 한 경우. */
public class ListingNotFoundException extends BusinessException {

    public ListingNotFoundException(Long listingId) {
        super(TransferErrorCode.LISTING_NOT_FOUND,
                TransferErrorCode.LISTING_NOT_FOUND.getMessage() + " (listingId=" + listingId + ")");
    }
}
