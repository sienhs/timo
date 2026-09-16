package com.ssafy.timo.domain.artist.service;

import com.ssafy.timo.domain.artist.dto.ArtistListRequestDto;
import com.ssafy.timo.domain.artist.dto.ArtistSummaryResponseDto;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 아티스트 조회 서비스.
 *
 * <p>아직 조회밖에 없어 클래스 전체를 {@code readOnly} 로 둔다. 쓰기 기능(등록·수정)이 생기면
 * 공연 쪽처럼 클래스는 기본 트랜잭션으로 두고 조회 메서드에만 {@code readOnly} 를 붙인다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ArtistServiceImpl implements ArtistService {

    private final ArtistRepository artistRepository;

    /**
     * 조건에 맞는 아티스트 목록을 페이지 단위로 조회한다.
     *
     * <p>{@link PagedModel} 로 감싸 내보낸다. {@code Page} 를 그대로 직렬화하면 {@code pageable.offset}
     * 처럼 클라이언트가 쓸 일 없는 내부 필드가 노출되고 구현에 따라 모양이 바뀌는데, 이 타입은
     * 그 문제를 피하려고 Spring Data 가 제공하는 응답 전용 타입이다.
     */
    @Override
    public PagedModel<ArtistSummaryResponseDto> findAll(ArtistListRequestDto request) {
        return new PagedModel<>(artistRepository
                .findPage(request.keywordOrNull(), request.toPageable())
                .map(ArtistSummaryResponseDto::from));
    }
}
