package com.ssafy.timo.domain.goods.controller;

import com.ssafy.timo.domain.goods.dto.GoodsDetailResponseDto;
import com.ssafy.timo.domain.goods.dto.GoodsListRequestDto;
import com.ssafy.timo.domain.goods.dto.GoodsSummaryResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;

/**
 * 굿즈(소장품) API 규약. 조회만 있다 — <b>완성된 굿즈는 수정·삭제하지 않는다.</b>
 *
 * <p>요청자는 {@link CurrentMember} 로만 받는다. 남의 굿즈를 보는 통로를 만들지 않으려고 경로나
 * 쿼리로 회원 식별자를 받지 않는다. 매핑과 검증 애노테이션은 여기에만 둔다.
 *
 * <p><b>만들기는 여기 없다.</b> 이미지 업로드는 {@link GoodsImageApi}, 생성은 {@link GoodsCreateApi} 가
 * 가진다. 둘 다 티켓 아래 경로다 — 굿즈는 티켓 1장에 1개 붙고, 어느 티켓인지가 그 요청의 주어다.
 *
 */
public interface GoodsApi {

    /** 내 굿즈 목록, 최신 순. */
    @GetMapping("/me")
    ResponseEntity<PagedModel<GoodsSummaryResponseDto>> findMyGoods(
            @Valid @ModelAttribute GoodsListRequestDto request,
            @CurrentMember Long memberId);

    /**
     * 굿즈 상세. <b>다른 기기에서 이 응답만으로 복원하는 기준 API</b> 라 저장된 필드를 전부 싣고,
     * 각 key 옆에 지금 읽을 수 있는 URL 을 함께 준다.
     *
     * <p>남의 굿즈는 404 다. 존재 여부를 알리지 않는다.
     */
    @GetMapping("/{goodsId}")
    ResponseEntity<GoodsDetailResponseDto> findMyGoodsDetail(
            @PathVariable Long goodsId,
            @CurrentMember Long memberId);
}
