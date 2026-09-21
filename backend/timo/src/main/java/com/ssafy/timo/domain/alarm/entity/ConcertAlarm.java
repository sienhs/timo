package com.ssafy.timo.domain.alarm.entity;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 회원이 공연의 알림을 받겠다고 신청한 기록. 회원, 공연, 알림 종류({@link AlarmType}) 한 조합에 한 행이다.
 *
 * <p>찜({@code ConcertWish}) 과는 별개다. 찜은 "관심 있음" 표시와 내 찜 목록이 뜻이고, 이 행이 있는
 * 공연만 알림의 대상이 된다. 찜을 하거나 풀어도 알림 신청은 그대로다.
 * <ul>
 *   <li>{@link AlarmType#CONCERT_OPEN}: 신청한 공연의 예매가 곧 열리면 알린다.</li>
 *   <li>{@link AlarmType#MARKET_LISTING}: 신청한 공연에 새 양도 매물이 올라오면 알린다.</li>
 * </ul>
 * 두 종류는 따로 신청하고 따로 해제한다. 예매한 공연의 일정 알림은 티켓 보유자 기준이라 이 행과 무관하다.
 *
 * <p>같은 조합을 두 번 넣는 것은 {@code uk_alarm_member_concert_type} 가 막는다. 신청 API 는 이 위반을
 * 성공으로 흡수해 재시도가 안전하다.
 */
@Getter
@Entity
@Table(name = "concert_alarm",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_alarm_member_concert_type",
                columnNames = {"member_id", "concert_id", "alarm_type"}),
        // 알림 스윕이 "이 공연의 이 종류 알림을 신청한 회원" 을 읽는 경로. 유니크 제약의 선두 컬럼이 member 라
        // 공연 쪽에서 찾으려면 따로 필요하다.
        indexes = @Index(name = "idx_alarm_concert_type", columnList = "concert_id, alarm_type"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ConcertAlarm extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "alarm_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "concert_id", nullable = false)
    private Concert concert;

    @Enumerated(EnumType.STRING)
    @Column(name = "alarm_type", nullable = false, length = 20)
    private AlarmType type;

    @Builder
    private ConcertAlarm(Member member, Concert concert, AlarmType type) {
        this.member = member;
        this.concert = concert;
        this.type = type;
    }
}
