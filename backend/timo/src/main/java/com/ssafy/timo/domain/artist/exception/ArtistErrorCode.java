package com.ssafy.timo.domain.artist.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/** 아티스트 도메인 에러 코드. */
@Getter
@RequiredArgsConstructor
public enum ArtistErrorCode implements BaseErrorCode {

    ARTIST_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 아티스트입니다.");

    private final HttpStatus status;
    private final String message;
}
