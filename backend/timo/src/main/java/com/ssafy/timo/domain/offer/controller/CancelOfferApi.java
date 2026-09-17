package com.ssafy.timo.domain.offer.controller;

import com.ssafy.timo.domain.offer.dto.CancelOfferListResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;

/**
 * 취소표 구매 기회 API 규약.
 *
 * <p>기회는 서버가 만들고(예매 취소 시 추첨) 당첨자는 조회만 한다. 수락 API 가 따로 없는 이유는
 * 구매 자체가 기존 좌석 선점과 예매 API 이기 때문이다 — 열린 기회가 있으면 그 좌석의 선점이
 * 당첨자에게만 허용되고, 결제되면 기회가 닫힌다. 앱은 이 목록으로 "어느 좌석을 언제까지" 만 알면 된다.
 */
public interface CancelOfferApi {

    /** 내게 열린 기회들. 기한이 가까운 것부터이고, 기한이 지난 것은 나오지 않는다. */
    @GetMapping("/me")
    ResponseEntity<CancelOfferListResponseDto> findMine(@CurrentMember Long memberId);
}
