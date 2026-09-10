package com.ssafy.timo.domain.concert.controller;

import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertDetailResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertListRequestDto;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import jakarta.validation.Valid;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ModelAttribute;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

/**
 * 공연 API 규약.
 *
 * <p>메서드 매핑과 요청 검증 애노테이션은 여기에만 둔다. 구현체(v1 실제 컨트롤러, v0 스텁)는
 * 클래스 레벨 {@code @RequestMapping} 으로 버전 경로만 정하고 이 메서드들을 그대로 오버라이드한다.
 * 자세한 이유는 {@link com.ssafy.timo.domain.venue.controller.VenueApi} 참고.
 */
public interface ConcertApi {

    /** 공연을 생성하고 생성된 리소스 위치를 Location 헤더로 알려준다. */
    @PostMapping
    ResponseEntity<CommandConcertResponseDto> create(@Valid @RequestBody CommandConcertRequestDto request);

    /**
     * 조건에 맞는 공연 목록을 페이지 단위로 조회한다.
     *
     * <p>조건은 모두 선택값이라 파라미터 없이 호출해도 된다. 상세 조회와 달리 조회수는 올라가지 않는다.
     */
    @GetMapping
    ResponseEntity<PagedModel<ConcertSummaryResponseDto>> findAll(@Valid @ModelAttribute ConcertListRequestDto request);

    /** 공연 상세를 조회한다. 조회할 때마다 조회수가 1 증가한다. */
    @GetMapping("/{concertId}")
    ResponseEntity<ConcertDetailResponseDto> find(@PathVariable Long concertId);
}
