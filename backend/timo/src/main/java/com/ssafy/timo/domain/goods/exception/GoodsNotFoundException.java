package com.ssafy.timo.domain.goods.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 굿즈가 없거나 요청자가 만든 것이 아닌 경우. 둘을 구분하지 않는다 — {@link GoodsErrorCode} 참고. */
public class GoodsNotFoundException extends BusinessException {

    public GoodsNotFoundException(Long goodsId) {
        super(GoodsErrorCode.GOODS_NOT_FOUND,
                GoodsErrorCode.GOODS_NOT_FOUND.getMessage() + " (goodsId=" + goodsId + ")");
    }
}
