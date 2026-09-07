package com.ssafy.timo.domain.venue.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 존재하지 않는 공연장을 참조한 경우. */
public class VenueNotFoundException extends BusinessException {

    public VenueNotFoundException(Long venueId) {
        super(VenueErrorCode.VENUE_NOT_FOUND,
                VenueErrorCode.VENUE_NOT_FOUND.getMessage() + " (venueId=" + venueId + ")");
    }
}
