package com.ssafy.timo.global.storage.exception;

import com.ssafy.timo.global.exception.BusinessException;

/** 업로드된 파일의 content type 이 허용 목록에 없는 경우. */
public class UnsupportedImageTypeException extends BusinessException {

    public UnsupportedImageTypeException(String contentType) {
        super(ImageStorageErrorCode.UNSUPPORTED_IMAGE_TYPE,
                ImageStorageErrorCode.UNSUPPORTED_IMAGE_TYPE.getMessage() + " (contentType=" + contentType + ")");
    }
}
