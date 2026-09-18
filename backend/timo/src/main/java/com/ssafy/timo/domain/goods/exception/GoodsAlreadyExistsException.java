package com.ssafy.timo.domain.goods.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 이 티켓의 굿즈가 이미 있는데 <b>다른</b> {@code clientGoodsId} 로 또 만들려 한 경우.
 *
 * <p>같은 {@code clientGoodsId} 면 여기까지 오지 않고 기존 굿즈를 돌려준다(재시도 멱등).
 */
public class GoodsAlreadyExistsException extends BusinessException {

    public GoodsAlreadyExistsException(Long ticketId) {
        super(GoodsErrorCode.GOODS_ALREADY_EXISTS,
                GoodsErrorCode.GOODS_ALREADY_EXISTS.getMessage() + " (ticketId=" + ticketId + ")");
    }
}
