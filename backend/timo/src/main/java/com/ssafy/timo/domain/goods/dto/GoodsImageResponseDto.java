package com.ssafy.timo.domain.goods.dto;

/**
 * 업로드한 이미지 한 장. 올린 순서대로 돌려준다.
 *
 * @param key 굿즈 생성 요청에 실을 값. 앱이 컬럼 자리와 {@code personLayers} 안에 직접 써넣는다
 * @param url 지금 읽을 수 있는 주소. 앱이 올린 직후 확인하는 용도다 - 저장은 {@code key} 로 한다
 */
public record GoodsImageResponseDto(String key, String url) {
}
