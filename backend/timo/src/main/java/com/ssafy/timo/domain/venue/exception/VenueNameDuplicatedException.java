package com.ssafy.timo.domain.venue.exception;

import com.ssafy.timo.global.exception.BusinessException;

/**
 * 이미 존재하는 공연장명으로 등록을 시도한 경우.
 *
 * <p>응답의 {@code exception} 필드에 구체적인 이름이 찍히도록 별도 타입으로 둔다.
 */
public class VenueNameDuplicatedException extends BusinessException {

    public VenueNameDuplicatedException(String name) {
        super(VenueErrorCode.VENUE_NAME_DUPLICATED,
                VenueErrorCode.VENUE_NAME_DUPLICATED.getMessage() + " (" + name + ")");
    }
}
