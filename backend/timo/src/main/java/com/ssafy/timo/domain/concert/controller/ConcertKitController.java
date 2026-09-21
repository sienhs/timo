package com.ssafy.timo.domain.concert.controller;

import com.ssafy.timo.domain.concert.dto.ConcertKitResponseDto;
import com.ssafy.timo.domain.concert.entity.ConcertImagePurpose;
import com.ssafy.timo.domain.concert.service.ConcertKitService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * 소재(kit) API (v1). 매핑과 규약은 {@link ConcertKitApi} 에 있고 여기서는 버전 경로만 정한다.
 *
 * <p>{@link ConcertController} 와 클래스 경로가 같다. 메서드 경로가 다르므로 스프링이 문제 삼지 않고,
 * 둘을 나눈 것은 공연 등록·조회와 소재가 서로 다른 시점에 다른 이유로 바뀌기 때문이다.
 */
@RestController
@RequestMapping("/api/v1/concerts")
@RequiredArgsConstructor
public class ConcertKitController implements ConcertKitApi {

    private final ConcertKitService concertKitService;

    @Override
    public ResponseEntity<ConcertKitResponseDto> findKit(Long concertId, Long memberId) {
        return ResponseEntity.ok(concertKitService.findKit(memberId, concertId));
    }

    @Override
    public ResponseEntity<ConcertKitResponseDto> addKitImages(Long concertId,
                                                              ConcertImagePurpose purpose,
                                                              List<MultipartFile> files) {
        ConcertKitResponseDto kit = concertKitService.addImages(concertId, purpose, files);

        return ResponseEntity.status(HttpStatus.CREATED).body(kit);
    }
}
