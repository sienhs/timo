package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;
import java.time.LocalDateTime;

/**
 * 운영 시간 중에 등록가를 바꾸려 한 경우. 마감 시각을 메시지에 실어 앱이 "언제 다시" 를 안내하게 한다.
 */
public class MarketOpenException extends BusinessException {

    public MarketOpenException(LocalDateTime closesAt) {
        super(TransferErrorCode.MARKET_OPEN,
                TransferErrorCode.MARKET_OPEN.getMessage() + " (closesAt=" + closesAt + ")");
    }
}
