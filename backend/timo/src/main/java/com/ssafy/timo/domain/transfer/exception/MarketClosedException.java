package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BusinessException;
import java.time.LocalDateTime;

/**
 * 운영 시간 밖에 등록·가격 수정·구매를 시도한 경우.
 *
 * <p>다음 여는 시각을 메시지에 싣는다. 앱이 "언제 다시 오라" 를 안내하려면 이 응답만으로
 * 충분해야 하고, 그 값은 {@code GET /market/hours} 를 한 번 더 부르지 않아도 알 수 있어야 한다.
 */
public class MarketClosedException extends BusinessException {

    public MarketClosedException(LocalDateTime opensAt) {
        super(TransferErrorCode.MARKET_CLOSED,
                TransferErrorCode.MARKET_CLOSED.getMessage() + " (opensAt=" + opensAt + ")");
    }
}
