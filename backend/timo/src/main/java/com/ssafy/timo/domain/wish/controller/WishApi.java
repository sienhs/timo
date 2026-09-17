package com.ssafy.timo.domain.wish.controller;

import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.domain.wish.dto.WishListRequestDto;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;

/**
 * 공연 찜 API 규약.
 *
 * <p>찜은 회원의 것이라 요청자를 {@link CurrentMember} 로만 받는다. 등록과 해제는 공연 식별자를 경로로
 * 받고 본문이 없으며, <b>둘 다 멱등이라 204</b> 다 — 이미 찜한 공연을 다시 찜해도, 찜하지 않은 공연을
 * 풀어도 같은 응답이다. 하트를 연타하거나 앱이 재시도해도 결과가 갈리지 않는다.
 *
 * <p>찜은 취소표 추첨의 모집단이다. 예매가 취소되면 그 공연을 찜한 회원 중 한 명이 구매 기회를 받는다.
 */
public interface WishApi {

    /** 찜한다. 없는 공연이면 404, 이미 찜했으면 그대로 204. */
    @PutMapping("/{concertId}")
    ResponseEntity<Void> add(@PathVariable Long concertId, @CurrentMember Long memberId);

    /** 찜을 푼다. 찜하지 않았어도 204. */
    @DeleteMapping("/{concertId}")
    ResponseEntity<Void> remove(@PathVariable Long concertId, @CurrentMember Long memberId);

    /** 내 찜 목록. 최근 찜한 순이고 공연 목록과 같은 요약 모양이다. */
    @GetMapping("/me")
    ResponseEntity<PagedModel<ConcertSummaryResponseDto>> findMine(
            @Valid @ModelAttribute WishListRequestDto request,
            @CurrentMember Long memberId);
}
