package com.ssafy.timo.domain.goods.controller;

import com.ssafy.timo.domain.goods.dto.CollectibleConcertResponseDto;
import com.ssafy.timo.domain.goods.service.GoodsQueryService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 소장품 카탈로그 API (v1). 매핑과 규약은 {@link CollectibleApi} 에 있고 여기서는 버전 경로만 정한다.
 *
 * <p>인증을 요구한다. {@code SecurityConfig} 의 {@code anyRequest().authenticated()} 가 받으므로
 * 경로를 따로 등록하지 않는다.
 */
@RestController
@RequestMapping("/api/v1/collectibles")
@RequiredArgsConstructor
public class CollectibleController implements CollectibleApi {

    private final GoodsQueryService goodsQueryService;

    @Override
    public ResponseEntity<List<CollectibleConcertResponseDto>> findCollectibleConcerts(Long memberId) {
        return ResponseEntity.ok(goodsQueryService.findCollectibleConcerts(memberId));
    }
}
