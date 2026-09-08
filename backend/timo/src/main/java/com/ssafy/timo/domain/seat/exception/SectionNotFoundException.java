package com.ssafy.timo.domain.seat.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 존재하지 않는 구역을 조회한 경우. */
public class SectionNotFoundException extends BusinessException {

    public SectionNotFoundException(Long sectionId) {
        super(SeatErrorCode.SECTION_NOT_FOUND,
                SeatErrorCode.SECTION_NOT_FOUND.getMessage() + " (sectionId=" + sectionId + ")");
    }
}
