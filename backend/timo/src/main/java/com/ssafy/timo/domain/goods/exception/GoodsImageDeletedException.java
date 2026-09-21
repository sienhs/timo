package com.ssafy.timo.domain.goods.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 생성 요청이 이미 지워진 이미지 key 를 가리키는 경우.
 *
 * <p>청소 배치가 지운 뒤에 그 key 로 굿즈를 만들려 한 상황이다. 그대로 저장하면 DB 에는 key 가 있는데
 * 객체가 없는 깨진 굿즈가 되므로 거절한다. 앱은 이미지를 다시 올린 뒤 새 key 로 만들면 된다.
 */
public class GoodsImageDeletedException extends BusinessException {

    public GoodsImageDeletedException() {
        super(GoodsErrorCode.GOODS_IMAGE_DELETED);
    }
}
