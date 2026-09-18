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
 * <p><b>TODO(S3 확정 후) — 생성 API 붙이기.</b> 이미지는 서버를 거치지 않는다: AI 서버가 만들어
 * S3 에 올리고 <b>key 만</b> 앱에 돌려주면, 앱이 그 key 들을 실어 여기로 온다. 그래서 multipart 가 아니라
 * JSON 한 덩어리이고, {@code CreateGoodsCommand} 가 그대로 요청 바디다.
 * <pre>
 * // GoodsCreateApi / GoodsCreateController (@RequestMapping("/api/v1/tickets"), 굿즈 패키지 안)
 * &#64;PostMapping("/{ticketId}/goods")
 * ResponseEntity&lt;GoodsDetailResponseDto&gt; create(
 *         &#64;PathVariable Long ticketId,
 *         &#64;Valid &#64;RequestBody CreateGoodsCommand command,
 *         &#64;CurrentMember Long memberId)
 * </pre>
 * 흐름: {@code GoodsService.create(memberId, ticketId, command)} → {@code GoodsCreateResult.created()} 가
 * {@code true} 면 201, 아니면 200 에 {@code goods()} 를 싣는다. {@code /api/v1/tickets} 접두는
 * {@code TicketController} 와 겹치지만 메서드 경로가 다르면 스프링이 문제 삼지 않으므로 티켓 도메인
 * 파일은 건드리지 않는다.
 *
 * <p>S3 가 확정되면 함께 정할 것: 앱이 보낸 key 를 어디까지 믿을지. 최소한 key 접두가 이 회원의 것인지
 * (예: {@code goods/{memberId}/...}) 는 서비스에서 가려야 남의 객체를 내 굿즈로 가리키는 일을 막는다.
 * 실제 존재 여부까지 볼지는 {@code ImageStorage} 에 그런 질의가 생긴 뒤에 정한다.
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
