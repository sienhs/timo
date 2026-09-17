package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;
import java.time.LocalDateTime;

/** 아직 마켓에 올라오지 않은 매물을 사려 한 경우. 올라오는 시각을 메시지에 싣는다. */
public class ListingNotOpenYetException extends BusinessException {

    public ListingNotOpenYetException(Long listingId, LocalDateTime visibleFrom) {
        super(TransferErrorCode.LISTING_NOT_OPEN_YET,
                TransferErrorCode.LISTING_NOT_OPEN_YET.getMessage()
                        + " (listingId=" + listingId + ", visibleFrom=" + visibleFrom + ")");
    }
}
