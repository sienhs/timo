package com.ssafy.timo.domain.goods.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 내 티켓은 맞지만 입장 완료({@code USED}) 상태가 아닌 경우.
 *
 * <p>어떤 상태였는지는 사용자에게 알릴 이유가 없는 내부 값이라 메시지에 담지 않는다.
 * 진단이 필요하면 호출부({@code GoodsService})가 로그로 남긴다.
 */
public class GoodsTicketNotUsedException extends BusinessException {

    public GoodsTicketNotUsedException() {
        super(GoodsErrorCode.GOODS_TICKET_NOT_USED);
    }
}
