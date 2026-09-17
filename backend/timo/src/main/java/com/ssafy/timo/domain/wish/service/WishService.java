package com.ssafy.timo.domain.wish.service;

import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.wish.dto.WishListRequestDto;
import com.ssafy.timo.domain.wish.entity.ConcertWish;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.web.PagedModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 공연 찜.
 *
 * <p>등록과 해제는 <b>멱등</b>이다. 하트는 연타되기 쉽고, 앱이 응답을 못 받고 재시도하면 같은 요청이
 * 두 번 온다. 이미 찜했으면 등록은 조용히 성공하고, 없는 찜을 해제해도 성공이다.
 */
@Service
@RequiredArgsConstructor
public class WishService {

    private final ConcertWishRepository concertWishRepository;
    private final ConcertRepository concertRepository;
    private final MemberRepository memberRepository;
    private final ImageStorage imageStorage;

    /**
     * 찜한다. 없는 공연이면 404.
     *
     * <p>존재 확인 뒤 INSERT 하므로 같은 회원의 요청이 겹치면 뒤의 것이 유니크 제약에 걸린다. 그건
     * "이미 찜했다" 와 같은 결과라 성공으로 흡수한다. 확인 없이 INSERT 만 하면 위반 원인이
     * 중복인지 다른 제약인지 구분할 수 없어 존재 확인을 앞에 둔다.
     */
    @Transactional
    public void add(Long memberId, Long concertId) {
        if (!concertRepository.existsById(concertId)) {
            throw new ConcertNotFoundException(concertId);
        }
        if (concertWishRepository.existsByMemberIdAndConcertId(memberId, concertId)) {
            return;
        }
        try {
            concertWishRepository.saveAndFlush(ConcertWish.builder()
                    .member(memberRepository.getReferenceById(memberId))
                    .concert(concertRepository.getReferenceById(concertId))
                    .build());
        } catch (DataIntegrityViolationException e) {
            // 확인과 INSERT 사이에 같은 회원의 다른 요청이 먼저 넣었다. 결과는 같다.
        }
    }

    /** 찜을 푼다. 없던 찜이어도 204 다. */
    @Transactional
    public void remove(Long memberId, Long concertId) {
        concertWishRepository.deleteByMemberIdAndConcertId(memberId, concertId);
    }

    /** 내 찜 목록. 최근 찜한 순이며 카드에 필요한 공연 요약을 그대로 준다. */
    @Transactional(readOnly = true)
    public PagedModel<ConcertSummaryResponseDto> findMine(Long memberId, WishListRequestDto request) {
        return new PagedModel<>(concertWishRepository
                .findPageOfMember(memberId, request.toPageable())
                .map(wish -> ConcertSummaryResponseDto.from(wish.getConcert(), imageStorage)));
    }
}
