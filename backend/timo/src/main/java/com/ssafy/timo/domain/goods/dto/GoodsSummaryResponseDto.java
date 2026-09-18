package com.ssafy.timo.domain.goods.dto;

import com.ssafy.timo.domain.goods.entity.GoodsEffect;
import java.time.LocalDateTime;
import tools.jackson.databind.JsonNode;

/**
 * 내 굿즈 목록의 한 장. 카드에 필요한 것만 싣는다 — 레이어와 키 전부는 상세({@link GoodsDetailResponseDto})에 있다.
 *
 * <p>{@link #concertSnapshot} 은 저장된 JSON 을 그대로 내보낸다. 서버가 구조를 정하지 않는다.
 */
public record GoodsSummaryResponseDto(
        Long goodsId,
        Long ticketId,
        String clientGoodsId,
        String previewUrl,
        GoodsEffect effectType,
        JsonNode concertSnapshot,
        LocalDateTime createdAt
) {
}
