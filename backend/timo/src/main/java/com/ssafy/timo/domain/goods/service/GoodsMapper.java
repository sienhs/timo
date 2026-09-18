package com.ssafy.timo.domain.goods.service;

import com.ssafy.timo.domain.goods.dto.GoodsDetailResponseDto;
import com.ssafy.timo.domain.goods.dto.GoodsSummaryResponseDto;
import com.ssafy.timo.domain.goods.entity.Goods;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * 엔티티를 응답으로 옮긴다. key → URL 변환과 JSON 문자열 → 트리 변환이 전부 여기서 일어난다.
 *
 * <p>{@code goods.getTicket().getId()} 처럼 연관의 <b>id 만</b> 읽는다. 지연 로딩 프록시는 id 를 이미
 * 알고 있어 추가 조회가 나가지 않으므로, 목록에서 한 장씩 옮겨도 쿼리가 늘지 않는다.
 */
@Component
@RequiredArgsConstructor
public class GoodsMapper {

    private final ImageStorage imageStorage;
    private final GoodsJson goodsJson;

    public GoodsSummaryResponseDto toSummary(Goods goods) {
        return new GoodsSummaryResponseDto(
                goods.getId(),
                goods.getTicket().getId(),
                goods.getClientGoodsId(),
                imageStorage.getUrl(goods.getPreviewKey()),
                goods.getEffectType(),
                goodsJson.read(goods.getConcertSnapshot()),
                goods.getCreatedAt());
    }

    public GoodsDetailResponseDto toDetail(Goods goods) {
        return new GoodsDetailResponseDto(
                goods.getId(),
                goods.getTicket().getId(),
                goods.getConcert().getId(),
                goods.getClientGoodsId(),
                goods.getBackgroundKey(),
                imageStorage.getUrl(goods.getBackgroundKey()),
                goods.getSourceBackgroundKey(),
                imageStorage.getUrl(goods.getSourceBackgroundKey()),
                goods.getPersonCompositeKey(),
                imageStorage.getUrl(goods.getPersonCompositeKey()),
                goods.getDepthMapKey(),
                imageStorage.getUrl(goods.getDepthMapKey()),
                goods.getPreviewKey(),
                imageStorage.getUrl(goods.getPreviewKey()),
                goods.getEffectType(),
                goodsJson.read(goods.getBackgroundFraming()),
                goodsJson.personLayersWithUrls(goodsJson.read(goods.getPersonLayers()), imageStorage),
                goodsJson.read(goods.getTransitionConfig()),
                goodsJson.read(goods.getRenderMetadata()),
                goodsJson.read(goods.getConcertSnapshot()),
                goods.getCreatedAt());
    }
}
