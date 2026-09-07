package com.ssafy.timo.global.storage;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

/**
 * S3 연동 전까지 쓰는 임시 {@link ImageStorage}.
 *
 * <p>key 앞에 설정된 base URL 만 붙여서 돌려주고, 삭제는 경고 로그만 남긴다.
 *
 * <p><b>TODO</b>: S3 업로드 방식이 정해지면 실제 구현체로 교체하고 이 클래스는 삭제한다.
 * 도메인은 {@link ImageStorage} 에만 의존하므로 교체 시 공연/이미지 코드는 손대지 않아도 된다.
 */
@Slf4j
@Component
public class PlaceholderImageStorage implements ImageStorage {

    private final String baseUrl;

    public PlaceholderImageStorage(@Value("${app.image.base-url:}") String baseUrl) {
        this.baseUrl = baseUrl;
    }

    @Override
    public String getUrl(String imageKey) {
        if (imageKey == null) {
            return null;
        }
        return baseUrl.isEmpty() ? imageKey : baseUrl + "/" + imageKey;
    }

    @Override
    public void delete(String imageKey) {
        log.warn("이미지 삭제가 아직 구현되지 않았습니다. imageKey={}", imageKey);
    }
}
