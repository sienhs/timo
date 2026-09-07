package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 같은 공연장에 이미 있는 구역명을 등록하려 한 경우. */
public class SectionNameDuplicatedException extends BusinessException {

    public SectionNameDuplicatedException(String name) {
        super(SeatErrorCode.SECTION_NAME_DUPLICATED,
                SeatErrorCode.SECTION_NAME_DUPLICATED.getMessage() + " (name=" + name + ")");
    }
}
