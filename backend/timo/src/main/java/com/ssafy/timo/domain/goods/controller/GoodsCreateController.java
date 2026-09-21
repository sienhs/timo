package com.ssafy.timo.domain.goods.controller;

import com.ssafy.timo.domain.goods.dto.CreateGoodsCommand;
import com.ssafy.timo.domain.goods.dto.GoodsCreateResult;
import com.ssafy.timo.domain.goods.dto.GoodsDetailResponseDto;
import com.ssafy.timo.domain.goods.service.GoodsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 굿즈 생성 API (v1). 매핑과 규약은 {@link GoodsCreateApi} 에 있고 여기서는 버전 경로만 정한다.
 *
 * <p>조회({@link GoodsController})와 경로 접두가 다르다 — 만들기는 티켓 아래, 조회는 굿즈 아래다.
 * 이유는 {@link GoodsCreateApi} 주석 참고.
 */
@RestController
@RequestMapping("/api/v1/tickets")
@RequiredArgsConstructor
public class GoodsCreateController implements GoodsCreateApi {

    private final GoodsService goodsService;

    /** 처음 만들었으면 201, 멱등 재전송이면 200. 본문은 둘 다 굿즈 상세다. */
    @Override
    public ResponseEntity<GoodsDetailResponseDto> create(Long ticketId,
                                                         CreateGoodsCommand command,
                                                         Long memberId) {
        GoodsCreateResult result = goodsService.create(memberId, ticketId, command);

        return ResponseEntity
                .status(result.created() ? HttpStatus.CREATED : HttpStatus.OK)
                .body(result.goods());
    }
}
