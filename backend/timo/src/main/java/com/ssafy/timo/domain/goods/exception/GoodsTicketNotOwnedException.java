package com.ssafy.timo.domain.goods.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 티켓이 없거나 지금 요청자의 것이 아닌 경우.
 *
 * <p>"지금" 이 중요하다. 예매자라도 양도해 버렸으면 아니고, 양도받았으면 예매자가 아니어도 맞다.
 * 판정 규칙은 {@code GoodsRepository.isCurrentOwner} 에 있다.
 */
public class GoodsTicketNotOwnedException extends BusinessException {

    public GoodsTicketNotOwnedException(Long ticketId) {
        super(GoodsErrorCode.GOODS_TICKET_NOT_OWNED,
                GoodsErrorCode.GOODS_TICKET_NOT_OWNED.getMessage() + " (ticketId=" + ticketId + ")");
    }
}
