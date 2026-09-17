package com.ssafy.timo.domain.wish.controller;

import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.domain.wish.dto.WishListRequestDto;
import com.ssafy.timo.domain.wish.service.WishService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 공연 찜 API (v1). 규약은 {@link WishApi} 에 있다.
 *
 * <p>모든 경로가 인증을 요구한다. {@code SecurityConfig} 의 {@code anyRequest().authenticated()} 가
 * 받으므로 경로를 따로 등록하지 않는다.
 */
@RestController
@RequestMapping("/api/v1/wishes")
@RequiredArgsConstructor
public class WishController implements WishApi {

    private final WishService wishService;

    @Override
    public ResponseEntity<Void> add(Long concertId, Long memberId) {
        wishService.add(memberId, concertId);
        return ResponseEntity.noContent().build();
    }

    @Override
    public ResponseEntity<Void> remove(Long concertId, Long memberId) {
        wishService.remove(memberId, concertId);
        return ResponseEntity.noContent().build();
    }

    @Override
    public ResponseEntity<PagedModel<ConcertSummaryResponseDto>> findMine(WishListRequestDto request, Long memberId) {
        return ResponseEntity.ok(wishService.findMine(memberId, request));
    }
}
