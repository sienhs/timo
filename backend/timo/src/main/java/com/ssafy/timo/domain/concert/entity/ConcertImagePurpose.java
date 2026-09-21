package com.ssafy.timo.domain.concert.entity;

/**
 * 공연 이미지의 쓰임새.
 *
 * <p>같은 표({@code concert_image})에 상세 화면용과 소장품 제작용 소재가 함께 산다. 둘을 가르는 것이
 * 이 값이고, <b>읽는 쪽은 반드시 용도로 걸러야 한다</b> — 걸르지 않으면 공개 API 인 공연 상세에
 * 소재 이미지가 섞여 나간다.
 */
public enum ConcertImagePurpose {

    /** 공연 상세 화면에 노출하는 이미지. 공개다. */
    DETAIL,

    /** 소장품 제작용 배경 소재. 그 공연 티켓을 가진 사람에게만 준다. */
    KIT_BACKGROUND,

    /** 소장품 제작용 인물 소재. 그 공연 티켓을 가진 사람에게만 준다. */
    KIT_PERSON;

    /** 소장품 제작용 소재인가. 상세 이미지와 가르는 유일한 기준이다. */
    public boolean isKit() {
        return this == KIT_BACKGROUND || this == KIT_PERSON;
    }
}
