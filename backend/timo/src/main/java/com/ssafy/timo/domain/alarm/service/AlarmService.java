package com.ssafy.timo.domain.alarm.service;

import com.ssafy.timo.domain.alarm.dto.AlarmListRequestDto;
import com.ssafy.timo.domain.alarm.dto.AlarmStatusResponseDto;
import com.ssafy.timo.domain.alarm.entity.AlarmType;
import com.ssafy.timo.domain.alarm.entity.ConcertAlarm;
import com.ssafy.timo.domain.alarm.repository.ConcertAlarmRepository;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.web.PagedModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 공연 알림 신청. 알림 종류({@link AlarmType}) 마다 따로 신청하고 따로 푼다.
 *
 * <p>신청과 해제는 <b>멱등</b>이다. 앱이 응답을 못 받고 재시도하면 같은 요청이 두 번 온다. 이미 신청했으면
 * 신청은 조용히 성공하고, 없는 신청을 해제해도 성공이다.
 */
@Service
@RequiredArgsConstructor
public class AlarmService {

    private final ConcertAlarmRepository concertAlarmRepository;
    private final ConcertRepository concertRepository;
    private final MemberRepository memberRepository;
    private final ImageStorage imageStorage;

    /**
     * 알림을 신청한다. 없는 공연이면 404.
     *
     * <p>존재 확인 뒤 INSERT 하므로 같은 회원의 요청이 겹치면 뒤의 것이 유니크 제약에 걸린다. 그건
     * "이미 신청했다" 와 같은 결과라 성공으로 흡수한다. 확인 없이 INSERT 만 하면 위반 원인이 중복인지
     * 다른 제약인지 구분할 수 없어 존재 확인을 앞에 둔다.
     */
    @Transactional
    public void add(Long memberId, Long concertId, AlarmType type) {
        if (!concertRepository.existsById(concertId)) {
            throw new ConcertNotFoundException(concertId);
        }
        if (concertAlarmRepository.existsByMemberIdAndConcertIdAndType(memberId, concertId, type)) {
            return;
        }
        try {
            concertAlarmRepository.saveAndFlush(ConcertAlarm.builder()
                    .member(memberRepository.getReferenceById(memberId))
                    .concert(concertRepository.getReferenceById(concertId))
                    .type(type)
                    .build());
        } catch (DataIntegrityViolationException e) {
            // 확인과 INSERT 사이에 같은 회원의 다른 요청이 먼저 넣었다. 결과는 같다.
        }
    }

    /** 알림 신청을 푼다. 같은 공연의 다른 종류는 그대로다. 없던 신청이어도 204 다. */
    @Transactional
    public void remove(Long memberId, Long concertId, AlarmType type) {
        concertAlarmRepository.deleteByMemberIdAndConcertIdAndType(memberId, concertId, type);
    }

    /**
     * 이 공연에 대한 내 알림 신청 상태. 신청한 종류만 {@code true} 다.
     *
     * <p>공연이 있는지는 확인하지 않는다. 없는 공연이면 신청이 있을 수 없으니 둘 다 {@code false} 이고, 존재 확인
     * 쿼리 하나를 아낀다. 화면은 공연 상세를 먼저 읽은 뒤 이 값을 묻는다.
     */
    @Transactional(readOnly = true)
    public AlarmStatusResponseDto findStatus(Long memberId, Long concertId) {
        return AlarmStatusResponseDto.from(
                concertAlarmRepository.findTypesByMemberIdAndConcertId(memberId, concertId));
    }

    /** 내가 이 종류의 알림을 신청한 공연 목록. 최근 신청한 순이며 카드에 필요한 공연 요약을 그대로 준다. */
    @Transactional(readOnly = true)
    public PagedModel<ConcertSummaryResponseDto> findMine(Long memberId, AlarmListRequestDto request) {
        return new PagedModel<>(concertAlarmRepository
                .findPageOfMember(memberId, request.type(), request.toPageable())
                .map(alarm -> ConcertSummaryResponseDto.from(alarm.getConcert(), imageStorage)));
    }
}
