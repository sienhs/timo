package com.ssafy.timo.domain.goods.controller;

import com.ssafy.timo.domain.goods.dto.GoodsDetailResponseDto;
import com.ssafy.timo.domain.goods.dto.GoodsListRequestDto;
import com.ssafy.timo.domain.goods.dto.GoodsSummaryResponseDto;
import com.ssafy.timo.domain.goods.service.GoodsQueryService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 굿즈 API (v1). 매핑과 규약은 {@link GoodsApi} 에 있고 여기서는 버전 경로만 정한다.
 *
 * <p>인증을 요구한다. {@code SecurityConfig} 의 {@code anyRequest().authenticated()} 가 받으므로
 * 경로를 따로 등록하지 않는다. 만들기는 {@code GoodsCreateController} 에 있다.
 */
@RestController
@RequestMapping("/api/v1/goods")
@RequiredArgsConstructor
public class GoodsController implements GoodsApi {

    private final GoodsQueryService goodsQueryService;

    @Override
    public ResponseEntity<PagedModel<GoodsSummaryResponseDto>> findMyGoods(GoodsListRequestDto request,
                                                                          Long memberId) {
        return ResponseEntity.ok(goodsQueryService.findMyGoods(memberId, request));
    }

    @Override
    public ResponseEntity<GoodsDetailResponseDto> findMyGoodsDetail(Long goodsId, Long memberId) {
        return ResponseEntity.ok(goodsQueryService.findMyGoodsDetail(memberId, goodsId));
    }
}
