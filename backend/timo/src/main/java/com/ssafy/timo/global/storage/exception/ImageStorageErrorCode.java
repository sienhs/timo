package com.ssafy.timo.global.storage.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/** 이미지 저장소 공통 에러 코드. 특정 도메인에 속하지 않아 {@code global.storage} 에 둔다. */
@Getter
@RequiredArgsConstructor
public enum ImageStorageErrorCode implements BaseErrorCode {

    UNSUPPORTED_IMAGE_TYPE(HttpStatus.BAD_REQUEST, "지원하지 않는 이미지 형식입니다. (jpg, png, webp, gif만 가능합니다.)");

    private final HttpStatus status;
    private final String message;
}
