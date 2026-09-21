package com.ssafy.timo.domain.goods.entity;

/**
 * 업로드 대장 행의 상태.
 *
 * <p>둘뿐이다. 대장은 "올린 이미지" 를 세는 장부이지 이미지의 생애를 그리는 상태 기계가 아니다.
 */
public enum GoodsUploadStatus {

    /** 저장소에 올라가 있다(고 대장이 알고 있다). 굿즈에 물렸는지는 여기서 구분하지 않는다. */
    UPLOADED,

    /** 청소 배치가 저장소에서 지웠다. 행은 남는다 - {@link GoodsUpload} 주석 참고. */
    DELETED
}
