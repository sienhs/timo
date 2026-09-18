package com.ssafy.timo.domain.goods.service;

import com.ssafy.timo.domain.goods.dto.CollectibleConcertResponseDto;
import com.ssafy.timo.domain.goods.dto.GoodsDetailResponseDto;
import com.ssafy.timo.domain.goods.dto.GoodsListRequestDto;
import com.ssafy.timo.domain.goods.dto.GoodsSummaryResponseDto;
import com.ssafy.timo.domain.goods.exception.GoodsNotFoundException;
import com.ssafy.timo.domain.goods.repository.GoodsRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 굿즈 조회. 전부 <b>요청자 본인 것</b>만이다.
 *
 * <p>얇은 이유는 소유자 판정과 굿즈 존재 여부가 전부 쿼리 안에 있기 때문이다
 * ({@code GoodsRepository}). 목록은 티켓 수와 무관하게 쿼리 한 번이다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class GoodsQueryService {

    private final GoodsRepository goodsRepository;
    private final GoodsMapper goodsMapper;
    private final ImageStorage imageStorage;

    /** 굿즈를 만들 수 있는 공연 — 내가 지금 가진 입장 완료 티켓들. 이미 만든 것은 {@code goodsId} 가 있다. */
    public List<CollectibleConcertResponseDto> findCollectibleConcerts(Long memberId) {
        return goodsRepository.findCollectibleConcerts(memberId).stream()
                .map(row -> CollectibleConcertResponseDto.from(row, imageStorage))
                .toList();
    }

    public PagedModel<GoodsSummaryResponseDto> findMyGoods(Long memberId, GoodsListRequestDto request) {
        return new PagedModel<>(goodsRepository
                .findMyGoods(memberId, request.toPageable())
                .map(goodsMapper::toSummary));
    }

    /** 남의 굿즈는 없는 것과 같은 404 다. */
    public GoodsDetailResponseDto findMyGoodsDetail(Long memberId, Long goodsId) {
        return goodsRepository.findByIdAndMemberId(goodsId, memberId)
                .map(goodsMapper::toDetail)
                .orElseThrow(() -> new GoodsNotFoundException(goodsId));
    }
}
