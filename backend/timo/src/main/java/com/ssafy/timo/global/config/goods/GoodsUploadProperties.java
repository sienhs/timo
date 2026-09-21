package com.ssafy.timo.global.config.goods;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.boot.context.properties.bind.DefaultValue;

/**
 * 굿즈 이미지 업로드 대장·청소 설정.
 *
 * <p>{@code uploadRetentionDays} 가 재는 것은 <b>업로드와 생성 호출 사이의 간격</b>이다. 그 사이에
 * 지우면 DB 에는 key 가 있는데 객체가 없는 깨진 굿즈가 나온다. 앱은 제작 세션이 끊기면 처음부터 다시
 * 만들고 이미지도 새로 올리므로 실제 간격은 분 단위인데, 짧게 잡아 얻는 것이 미완성 제작분의 저장소
 * 용량뿐이라 넉넉히 잡았다.
 *
 * @param uploadRetentionDays 이 일수가 지난 업로드분부터 청소 대상이다. 1 이상이어야 한다
 * @param cleanupEnabled      false 이면 청소 배치가 아무것도 지우지 않는다
 */
@ConfigurationProperties(prefix = "app.goods")
public record GoodsUploadProperties(@DefaultValue("7") int uploadRetentionDays,
                                    @DefaultValue("true") boolean cleanupEnabled) {

    public GoodsUploadProperties {
        if (uploadRetentionDays < 1) {
            throw new IllegalArgumentException(
                    "app.goods.upload-retention-days 는 1 이상이어야 한다: " + uploadRetentionDays);
        }
    }
}
