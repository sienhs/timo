package com.ssafy.timo.domain.artist.controller;

import com.ssafy.timo.domain.artist.dto.ArtistListRequestDto;
import com.ssafy.timo.domain.artist.dto.ArtistSummaryResponseDto;
import jakarta.validation.Valid;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;

/**
 * 아티스트 API 규약.
 *
 * <p>메서드 매핑과 요청 검증 애노테이션은 여기에만 둔다. 구현체(v1 실제 컨트롤러, v0 스텁)는
 * 클래스 레벨 {@code @RequestMapping} 으로 버전 경로만 정하고 이 메서드들을 그대로 오버라이드한다.
 * 자세한 이유는 {@link com.ssafy.timo.domain.venue.controller.VenueApi} 참고.
 */
public interface ArtistApi {

    /**
     * 조건에 맞는 아티스트 목록을 페이지 단위로 조회한다.
     *
     * <p>조건은 모두 선택값이라 파라미터 없이 호출해도 첫 페이지가 나온다.
     */
    @GetMapping
    ResponseEntity<PagedModel<ArtistSummaryResponseDto>> findAll(@Valid @ModelAttribute ArtistListRequestDto request);
}
