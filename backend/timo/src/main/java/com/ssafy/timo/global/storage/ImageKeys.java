package com.ssafy.timo.global.storage;

import com.ssafy.timo.global.storage.exception.UnsupportedImageTypeException;

import java.util.Map;
import java.util.UUID;

/**
 * {@link ImageStorage} 구현체들이 공유하는 key 생성 규칙.
 *
 * <p>업로드마다 무작위 key 를 새로 만들어, 클라이언트가 저장 경로나 파일명을 좌우하지 못하게 한다.
 * 허용하는 이미지 형식도 여기 한 곳에서만 정의해 구현체 간에 기준이 갈리지 않게 한다.
 */
final class ImageKeys {

    private static final Map<String, String> EXTENSIONS_BY_CONTENT_TYPE = Map.of(
            "image/jpeg", "jpg",
            "image/png", "png",
            "image/webp", "webp",
            "image/gif", "gif"
    );

    private ImageKeys() {
    }

    /**
     * {@code keyPrefix/무작위값.확장자} 형태의 key 를 만든다.
     *
     * @throws UnsupportedImageTypeException {@code contentType} 이 허용 목록에 없으면(누락 포함)
     */
    static String generate(String keyPrefix, String contentType) {
        String extension = contentType == null ? null : EXTENSIONS_BY_CONTENT_TYPE.get(contentType);
        if (extension == null) {
            throw new UnsupportedImageTypeException(contentType);
        }

        return keyPrefix + "/" + UUID.randomUUID() + "." + extension;
    }
}
