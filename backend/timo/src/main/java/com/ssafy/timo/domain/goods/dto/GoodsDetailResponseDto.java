package com.ssafy.timo.domain.goods.dto;

import com.ssafy.timo.domain.goods.entity.GoodsEffect;
import java.time.LocalDateTime;
import tools.jackson.databind.JsonNode;

/**
 * 굿즈 상세. <b>다른 기기에서 이 응답만으로 복원하는 기준 API</b> 라 저장된 필드를 전부 싣는다.
 *
 * <p>각 이미지는 <b>key 와 URL 을 함께</b> 준다. key 는 앱이 다시 올리거나 비교할 때의 식별자이고,
 * URL 은 지금 당장 읽을 주소다(presigned 라면 만료될 수 있어 key 를 버리면 안 된다).
 * {@link #personLayers} 안의 {@code cutoutKey}·{@code depthMapKey}·{@code parts[].partMapKey} 도 같은
 * 규칙으로 옆에 {@code *Url} 이 붙는다. 나머지 JSON 구조는 저장된 그대로다.
 */
public record GoodsDetailResponseDto(
        Long goodsId,
        Long ticketId,
        Long concertId,
        String clientGoodsId,
        String backgroundKey,
        String backgroundUrl,
        String sourceBackgroundKey,
        String sourceBackgroundUrl,
        String personCompositeKey,
        String personCompositeUrl,
        String depthMapKey,
        String depthMapUrl,
        String previewKey,
        String previewUrl,
        GoodsEffect effectType,
        JsonNode backgroundFraming,
        JsonNode personLayers,
        JsonNode transitionConfig,
        JsonNode renderMetadata,
        JsonNode concertSnapshot,
        LocalDateTime createdAt
) {
}
