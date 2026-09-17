package com.ssafy.timo.global.storage;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

/**
 * {@code local} 과 {@code test} 에서만 뜨는 {@link ImageStorage}. 로컬은 정적 리소스를, 테스트는
 * 가짜 CDN 도메인을 key 앞에 그대로 붙여 URL 을 만들고, 삭제는 경고 로그만 남긴다 - 둘 다 실제
 * S3 버킷이 필요 없다.
 *
 * <p>{@link S3ImageStorage} 와 프로파일 조건이 서로 여집합이어야 한다는 점은 그쪽 주석 참고.
 */
@Slf4j
@Component
@Profile({"local", "test"})
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

    /**
     * 실제로 저장하지 않는다 - {@code local}/{@code test} 는 S3 버킷이 없다. content type 검증은
     * {@link S3ImageStorage} 와 같은 기준({@link ImageKeys})으로 하므로, 업로드 API 를 테스트할 때
     * 지원하지 않는 형식은 여기서도 똑같이 걸러진다.
     */
    @Override
    public String upload(String keyPrefix, MultipartFile file) {
        String key = ImageKeys.generate(keyPrefix, file.getContentType());
        log.warn("이미지 업로드가 아직 구현되지 않았습니다. key={}", key);

        return key;
    }
}
