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
 *
 * <p><b>key 만들기와 쓰기가 나뉘어 있는 이유.</b> 굿즈 업로드는 올린 key 를 대장 테이블에 먼저 적고
 * 저장소에 쓴다({@code GoodsUploadService}). 순서가 반대면 대장에 없는 key 가 생겨 어느 배치도 찾지
 * 못하는 고아가 된다. 적으려면 쓰기 전에 key 가 있어야 하므로 {@link #newKey} 로 key 만 먼저 받는다.
 * 그 사정이 없는 호출 쪽은 둘을 묶은 {@link #upload} 를 그대로 쓴다.
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
     * 새 key 를 만들어 돌려준다. <b>저장소에는 아무것도 쓰지 않는다.</b> 형식 검증은 여기서 한다 -
     * 허용하지 않는 형식이면 key 도 나오지 않으므로 거절된 파일은 대장에도 남지 않는다.
     *
     * @param keyPrefix key 의 접두어. 슬래시로 끝나지 않아야 한다(예: {@code "concert/42/poster"}).
     * @throws UnsupportedImageTypeException 지원하지 않는 이미지 형식이면
     */
    String newKey(String keyPrefix, MultipartFile file);

    /**
     * 이미 정해진 key 에 파일을 쓴다. {@link #newKey} 가 만든 key 를 넘긴다 - 클라이언트가 보낸 값을
     * 그대로 넘기면 저장 경로를 클라이언트가 좌우하게 되므로 그렇게 쓰지 않는다.
     */
    void uploadTo(String imageKey, MultipartFile file);

    /**
     * 이미지 파일을 저장하고 저장된 key 를 돌려준다. key 는 {@code keyPrefix} 로 시작하고 뒤에
     * 저장소가 만든 무작위 값과 확장자가 붙는다 - 원본 파일명은 key 에 쓰이지 않는다.
     *
     * @param keyPrefix key 의 접두어. 슬래시로 끝나지 않아야 한다(예: {@code "concert/42/poster"}).
     * @throws UnsupportedImageTypeException 지원하지 않는 이미지 형식이면
     */
    default String upload(String keyPrefix, MultipartFile file) {
        String imageKey = newKey(keyPrefix, file);
        uploadTo(imageKey, file);

        return imageKey;
    }
}
