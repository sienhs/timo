package com.ssafy.timo.domain.venue.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/** 공연장 도메인 에러 코드. */
@Getter
@RequiredArgsConstructor
public enum VenueErrorCode implements BaseErrorCode {

    VENUE_NAME_DUPLICATED(HttpStatus.CONFLICT, "이미 등록된 공연장명입니다.");

    private final HttpStatus status;
    private final String message;
}
