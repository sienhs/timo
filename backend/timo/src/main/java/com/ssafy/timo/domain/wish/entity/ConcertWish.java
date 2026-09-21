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
 * <p>찜은 "이 공연에 관심 있음" 이라는 뜻이고, 내 찜 목록에 쓰인다. 기기에만 두면 기기를 바꿀 때
 * 사라지므로 서버에 둔다.
 *
 * <p><b>알림과는 무관하다.</b> 예매 오픈 안내와 양도 매물 알림은 {@code ConcertAlarm} 으로 따로 신청한
 * 회원에게만 나가므로, 찜을 하거나 풀어도 알림은 바뀌지 않는다.
 *
 * <p>원래는 취소표 추첨의 모집단이기도 했으나 추첨을 없애면서(2026-09-18 기획 변경) 그 용도는 사라졌다.
 * 지금은 취소된 좌석이 랜덤한 시각에 그냥 다시 열리므로 찜과 무관하다.
 *
 * <p>같은 쌍을 두 번 넣는 것은 {@code uk_wish_member_concert} 가 막는다. 등록 API 는 이 위반을
 * 성공으로 흡수해 재시도가 안전하다.
 *
 * <p><b>{@code idx_wish_concert} 를 두는 이유.</b> 이 인덱스를 타는 조회 쿼리는 없다. 내 찜 목록은
 * {@code member_id} 로 읽어서 유니크 제약 {@code uk_wish_member_concert} (선두 컬럼이 {@code member_id}) 가
 * 처리한다. 그래도 남기는 것은 {@code concert_id} 외래 키 때문이다. MySQL(InnoDB) 은 외래 키 컬럼에 그 컬럼이
 * 선두인 인덱스를 요구하고, 없으면 자동으로 하나 만든다. 이 인덱스를 명시해 두면 이름을 우리가 정하고, 공연을
 * 삭제할 때 자식 행({@code concert_wish}) 을 확인하는 검사가 풀 스캔이 되지 않는다. 다만 {@code init.sql} 의
 * 운영 DDL 에는 외래 키 선언이 없고, 외래 키는 엔티티 기반 스키마 생성(local, test) 에서만 만들어진다.
 */
@Getter
@Entity
@Table(name = "concert_wish",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_wish_member_concert",
                columnNames = {"member_id", "concert_id"}),
        // concert_id 외래 키용 인덱스. 이유는 클래스 javadoc 에 있다.
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
