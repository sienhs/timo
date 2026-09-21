package com.ssafy.timo.domain.goods.controller;

import com.ssafy.timo.domain.goods.dto.CreateGoodsCommand;
import com.ssafy.timo.domain.goods.dto.GoodsDetailResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

/**
 * 굿즈(소장품) 생성 API 규약. 조회는 {@link GoodsApi}, 이미지 업로드는 {@link GoodsImageApi} 에 있다.
 *
 * <p><b>경로가 티켓 아래인 이유.</b> 굿즈는 입장을 마친 티켓 1장에 1개 붙는다. 어느 티켓인지가
 * 요청의 주어라 경로에 두고, 만드는 사람은 {@link CurrentMember} 로만 받는다 — 남의 이름으로
 * 만드는 통로를 열지 않으려고 회원 식별자는 경로나 바디로 받지 않는다. 공연도 요청에 없다.
 * 티켓에서 서버가 정한다.
 *
 * <p>{@code /api/v1/tickets} 접두가 {@code TicketController} 와 겹치지만 메서드 경로가 다르면
 * 스프링이 문제 삼지 않는다. 티켓 도메인 파일은 건드리지 않는다.
 *
 * <p><b>파일을 받지 않는다.</b> 이미지는 앱이 {@link GoodsImageApi} 로 먼저 올리고, 받은 key 를
 * 이 요청의 JSON 에 써넣는다. 이미지를 생성 요청에 파트로 싣지 않는 이유는 레이어 이미지 때문이다 —
 * {@code personLayers} 안의 {@code cutoutKey}·{@code partMapKey} 는 레이어와 파츠 수에 따라 장수가
 * 달라 파트 이름을 미리 못 박을 수 없고, 서버가 파트 이름을 JSON 자리로 해석하기 시작하면 앱의
 * 레이어 스키마가 서버 코드에 박힌다. 멱등 재전송이 수십 MB 를 다시 올리지 않는 것도 이 모양의 값이다.
 */
public interface GoodsCreateApi {

    /**
     * 굿즈 생성. 요청 바디는 업로드에서 받은 key 를 앱이 채워 넣은 {@link CreateGoodsCommand} 다.
     *
     * <p>처음 만들면 201, 같은 {@code clientGoodsId} 로 다시 보내면 저장하지 않고 기존 굿즈를 200 으로
     * 돌려준다(멱등). 본문 모양은 둘 다 굿즈 상세로 같다.
     *
     * <p>400 {@code personLayers} 위반 / 404 없거나 내 티켓 아님 / 409 입장 전·이미 만든 티켓·청소
     * 배치가 이미 지운 이미지를 가리킴.
     */
    @PostMapping("/{ticketId}/goods")
    ResponseEntity<GoodsDetailResponseDto> create(
            @PathVariable Long ticketId,
            @Valid @RequestBody CreateGoodsCommand command,
            @CurrentMember Long memberId);
}
