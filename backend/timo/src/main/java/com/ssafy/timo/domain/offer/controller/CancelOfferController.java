package com.ssafy.timo.domain.offer.controller;

import com.ssafy.timo.domain.offer.dto.CancelOfferListResponseDto;
import com.ssafy.timo.domain.offer.service.CancelOfferService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** 취소표 구매 기회 API (v1). 규약은 {@link CancelOfferApi} 에 있다. 모든 경로가 인증을 요구한다. */
@RestController
@RequestMapping("/api/v1/offers")
@RequiredArgsConstructor
public class CancelOfferController implements CancelOfferApi {

    private final CancelOfferService cancelOfferService;

    @Override
    public ResponseEntity<CancelOfferListResponseDto> findMine(Long memberId) {
        return ResponseEntity.ok(cancelOfferService.findMine(memberId));
    }
}
