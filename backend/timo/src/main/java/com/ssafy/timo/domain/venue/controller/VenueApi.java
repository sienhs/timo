package com.ssafy.timo.domain.venue.controller;

import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.dto.CommandVenueResponseDto;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

/**
 * 공연장 API 규약.
 *
 * <p>메서드 매핑과 요청 검증 애노테이션은 여기에만 둔다. 구현체(v1 실제 컨트롤러, v0 스텁)는
 * 클래스 레벨 {@code @RequestMapping} 으로 버전 경로만 정하고 이 메서드들을 그대로 오버라이드한다.
 * 그래야 스텁과 실제 API 의 요청·응답 모양이 컴파일 시점에 같아진다.
 *
 * <p>스프링 MVC 는 인터페이스에 선언된 {@code @PostMapping}·{@code @RequestBody}·{@code @Valid}
 * 를 구현 클래스 메서드에서 그대로 읽는다. 구현체가 파라미터 제약({@code @NotBlank} 등)을 다시
 * 붙이면 Bean Validation 이 "오버라이드 메서드의 제약 재정의" 로 거부하므로 붙이지 않는다.
 */
public interface VenueApi {

    /** 공연장을 등록하고 생성된 리소스 위치를 Location 헤더로 알려준다. */
    @PostMapping
    ResponseEntity<CommandVenueResponseDto> register(@Valid @RequestBody CommandVenueRequestDto request);
}
