package com.ssafy.timo.domain.goods.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** {@code personLayers} 가 규칙(배열, 길이 ≤ 2, {@code layerOrder} 중복 없음)을 어긴 경우. */
public class GoodsInvalidLayersException extends BusinessException {

    public GoodsInvalidLayersException(String reason) {
        super(GoodsErrorCode.GOODS_INVALID_LAYERS,
                GoodsErrorCode.GOODS_INVALID_LAYERS.getMessage() + " (" + reason + ")");
    }
}
