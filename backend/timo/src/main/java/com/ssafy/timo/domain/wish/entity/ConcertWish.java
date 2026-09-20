package com.ssafy.timo.domain.wish.entity;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
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
 * 회원이 공연을 찜한 기록. 회원과 공연 한 쌍에 한 행이다.
 *
 * <p>찜은 "이 공연에 관심 있음" 이라는 한 가지 뜻이고, 그 신호를 여러 곳이 읽는다.
 * <ul>
 *   <li>내 찜 목록. 기기에만 두면 기기를 바꿀 때 사라지므로 서버에 둔다.</li>
 *   <li>예매 오픈 안내 알림의 대상. 찜한 공연의 예매가 곧 열리면 알린다.</li>
 *   <li>양도 매물 알림의 대상. 찜한 공연에 새 양도 매물이 올라오면 알린다.</li>
 * </ul>
 * 그래서 <b>찜을 해제하면 위 알림도 함께 멈춘다.</b> 알림을 따로 신청하는 절차나 수신 설정은 없다.
 *
 * <p>원래는 취소표 추첨의 모집단이기도 했으나 추첨을 없애면서(2026-09-18 기획 변경) 그 용도는 사라졌다.
 * 지금은 취소된 좌석이 랜덤한 시각에 그냥 다시 열리므로 찜과 무관하다.
 *
 * <p>같은 쌍을 두 번 넣는 것은 {@code uk_wish_member_concert} 가 막는다. 등록 API 는 이 위반을
 * 성공으로 흡수해 재시도가 안전하다.
 */
@Getter
@Entity
@Table(name = "concert_wish",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_wish_member_concert",
                columnNames = {"member_id", "concert_id"}),
        // 알림 스윕이 "이 공연을 찜한 회원" 을 읽는 경로(예매 오픈 안내, 양도 매물). 유니크 제약의 선두 컬럼이
        // member 라 공연 쪽에서 찾으려면 따로 필요하다.
        indexes = @Index(name = "idx_wish_concert", columnList = "concert_id"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ConcertWish extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "wish_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "concert_id", nullable = false)
    private Concert concert;

    @Builder
    private ConcertWish(Member member, Concert concert) {
        this.member = member;
        this.concert = concert;
    }
}
