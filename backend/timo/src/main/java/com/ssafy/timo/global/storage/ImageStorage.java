package com.ssafy.timo.global.storage;

import com.ssafy.timo.global.storage.exception.UnsupportedImageTypeException;
import org.springframework.web.multipart.MultipartFile;

/**
 * 이미지 저장소 포트.
 *
 * <p>도메인은 이미지의 <b>key</b> 만 들고 있고, 그 key 가 어디에 어떻게 놓여 있는지는 이 인터페이스 뒤로 숨긴다.
 *
 * <p>업로드는 서버 경유다 - 공연·아티스트 등 소속 엔티티의 id 를 key 에 넣어야 하는데, 그 id 는 엔티티가
 * 저장된 뒤에야 생기므로 클라이언트가 key 를 미리 알 수 없다(presigned URL 이 못 쓰는 이유). 그래서
 * {@code keyPrefix} 는 호출 쪽(서비스 계층)이 정해서 넘기고, 이 뒤에 저장소가 무작위 값을 붙여 최종 key 를
 * 만든다 - 클라이언트가 저장 경로나 파일명을 좌우하지 못하게 하기 위해서다.
 */
public interface ImageStorage {

    /**
     * 저장된 이미지에 접근할 수 있는 URL 을 돌려준다.
     *
     * @param imageKey 저장소 내 객체 key. {@code null} 이면 {@code null} 을 돌려준다.
     */
    String getUrl(String imageKey);

    /** 저장된 이미지를 삭제한다. 이미 없는 key 여도 예외를 던지지 않는다. */
    void delete(String imageKey);

    /**
     * 이미지 파일을 저장하고 저장된 key 를 돌려준다. key 는 {@code keyPrefix} 로 시작하고 뒤에
     * 저장소가 만든 무작위 값과 확장자가 붙는다 - 원본 파일명은 key 에 쓰이지 않는다.
     *
     * @param keyPrefix key 의 접두어. 슬래시로 끝나지 않아야 한다(예: {@code "concert/42/poster"}).
     * @throws UnsupportedImageTypeException 지원하지 않는 이미지 형식이면
     */
    String upload(String keyPrefix, MultipartFile file);
}
