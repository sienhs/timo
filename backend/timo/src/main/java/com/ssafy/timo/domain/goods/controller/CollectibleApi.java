package com.ssafy.timo.domain.goods.controller;

import com.ssafy.timo.domain.goods.dto.CollectibleConcertResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * 소장품(굿즈) 카탈로그 API 규약. 앱의 "소장품 만들기" 화면이 부른다.
 *
 * <p>요청자는 {@link CurrentMember} 로만 받는다. 매핑은 여기에만 둔다({@code TicketApi} 와 같다).
 */
public interface CollectibleApi {

    /**
     * 굿즈를 만들 수 있는 공연 목록 — 내가 지금 가진 티켓 중 입장 완료({@code USED})한 것.
     *
     * <p>원소는 공연이 아니라 <b>티켓</b> 단위다. 같은 공연을 두 장 가졌으면 두 줄이고, 굿즈는 티켓마다
     * 하나다. 이미 만든 티켓은 {@code goodsId} 가 채워져 있어 상세로 바로 보낼 수 있다.
     * 페이지 없이 전부 내려준다 — 한 사람이 입장까지 마친 티켓은 많아야 수십 장이다.
     *
     * <p>{@code videoUrl} 은 공연에 영상 컬럼이 없어 지금은 항상 {@code null} 이다.
     */
    @GetMapping("/concerts")
    ResponseEntity<List<CollectibleConcertResponseDto>> findCollectibleConcerts(@CurrentMember Long memberId);
}
