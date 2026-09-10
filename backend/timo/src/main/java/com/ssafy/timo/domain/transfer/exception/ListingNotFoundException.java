package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 매물로 등록돼 있지 않은 tokenId 를 구매·취소하려 한 경우. 티켓 자체가 없을 때도 이 예외다. */
public class ListingNotFoundException extends BusinessException {

    public ListingNotFoundException(String tokenId) {
        super(TransferErrorCode.LISTING_NOT_FOUND,
                TransferErrorCode.LISTING_NOT_FOUND.getMessage() + " (tokenId=" + tokenId + ")");
    }
}
