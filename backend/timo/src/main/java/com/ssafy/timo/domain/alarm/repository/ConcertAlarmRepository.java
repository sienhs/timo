package com.ssafy.timo.domain.alarm.repository;

import com.ssafy.timo.domain.alarm.dto.AlarmedConcertRow;
import com.ssafy.timo.domain.alarm.entity.AlarmType;
import com.ssafy.timo.domain.alarm.entity.ConcertAlarm;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;

public interface ConcertAlarmRepository extends JpaRepository<ConcertAlarm, Long> {

    /**
     * 내가 이 종류의 알림을 신청한 공연 목록. 공연 카드에 공연장 이름이 실리므로 공연과 공연장을 함께 읽는다
     * (다대일만 fetch join).
     *
     * <p>정렬은 최근 신청한 순이고 {@code id} 를 덧붙인다. 같은 초에 두 건을 신청하면 순서가 흔들려
     * 페이지를 넘길 때 같은 카드가 두 번 나올 수 있다.
     */
    @Query(value = """
            select a
              from ConcertAlarm a
              join fetch a.concert c
              join fetch c.venue
             where a.member.id = :memberId
               and a.type = :type
             order by a.createdAt desc, a.id desc
            """,
            countQuery = """
            select count(a) from ConcertAlarm a where a.member.id = :memberId and a.type = :type
            """)
    Page<ConcertAlarm> findPageOfMember(@Param("memberId") Long memberId, @Param("type") AlarmType type,
                                        Pageable pageable);

    /**
     * 내가 이 공연에 신청한 알림 종류들. 공연 상세 화면이 종류별 신청 상태를 그리는 데 쓴다. 유니크 제약
     * {@code uk_alarm_member_concert_type} 의 앞 두 컬럼으로 읽는다. 정렬은 의미가 없어 하지 않는다.
     */
    @Query("select a.type from ConcertAlarm a where a.member.id = :memberId and a.concert.id = :concertId")
    List<AlarmType> findTypesByMemberIdAndConcertId(@Param("memberId") Long memberId,
                                                    @Param("concertId") Long concertId);

    boolean existsByMemberIdAndConcertIdAndType(Long memberId, Long concertId, AlarmType type);

    /** 알림 해제. 영향 행 수를 돌려주므로 없던 신청을 지워도 예외가 아니다 — 해제는 멱등이어야 한다. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("""
            delete from ConcertAlarm a
             where a.member.id = :memberId and a.concert.id = :concertId and a.type = :type
            """)
    int deleteByMemberIdAndConcertIdAndType(@Param("memberId") Long memberId, @Param("concertId") Long concertId,
                                            @Param("type") AlarmType type);

    /**
     * 이 공연의 이 종류 알림을 신청한 회원 id. 예매 오픈 안내 알림의 대상이 여기서 나온다. 정렬은 의미가 없어
     * 하지 않는다.
     */
    @Query("select a.member.id from ConcertAlarm a where a.concert.id = :concertId and a.type = :type")
    List<Long> findMemberIdsByConcertIdAndType(@Param("concertId") Long concertId, @Param("type") AlarmType type);

    /**
     * 여러 공연의 이 종류 알림 신청을 한 번에. 어느 공연의 신청인지 알아야 회원마다 신청한 공연을 모을 수 있어서
     * 회원 id 와 공연 id 를 함께 돌려준다. 양도 매물 알림이 쓴다. 정렬은 의미가 없어 하지 않는다.
     *
     * <p>{@code idx_alarm_concert_type} 를 탄다. 호출부가 공연이 하나도 없을 때는 부르지 않는 편이 낫다.
     */
    @Query("""
            select a.member.id as memberId, a.concert.id as concertId
              from ConcertAlarm a
             where a.concert.id in :concertIds
               and a.type = :type
            """)
    List<AlarmedConcertRow> findAllByConcertIdInAndType(@Param("concertIds") Collection<Long> concertIds,
                                                        @Param("type") AlarmType type);
}
