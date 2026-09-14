package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 남의 매물을 취소하려 한 경우.
 *
 * <p>{@link NotTicketOwnerException} 과 나누어 둔다. 그쪽은 "내 티켓이 아니다"(등록 시), 이쪽은
 * "내가 올린 매물이 아니다"(취소 시)라 화면에 보여 줄 말이 다르다.
 */
public class NotListingSellerException extends BusinessException {

    public NotListingSellerException(Long listingId) {
        super(TransferErrorCode.NOT_LISTING_SELLER,
                TransferErrorCode.NOT_LISTING_SELLER.getMessage() + " (listingId=" + listingId + ")");
    }
}
