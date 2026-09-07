package com.ssafy.timo.global.storage;

/**
 * 이미지 저장소 포트.
 *
 * <p>도메인은 이미지의 <b>key</b> 만 들고 있고, 그 key 가 어디에 어떻게 놓여 있는지는 이 인터페이스 뒤로 숨긴다.
 * presigned URL 방식(클라이언트가 S3 에 직접 업로드)이든 서버 경유 업로드든 "정해진 key 에 객체가 존재한다"는
 * 점은 같으므로, 업로드 방식이 확정돼도 이 인터페이스와 저장된 데이터는 그대로 쓸 수 있다.
 *
 * <p>업로드(발급/전송) 자체는 방식이 정해지지 않아 아직 이 포트에 넣지 않았다. 확정되면
 * {@code issueUploadUrl(...)} 또는 {@code upload(...)} 를 여기에 추가한다.
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
}
