package com.ssafy.timo.domain.transfer.entity;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.seat.entity.Section;
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
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 양도 매물 한 건. 매물의 생명주기는 이 테이블이 정본이다.
 *
 * <p><b>외부에 나가는 식별자는 {@code listingId} 하나뿐이다.</b> {@code ticketId} 가 응답에 실리면
 * 원 예매 건을 역추적할 수 있고, 같은 티켓의 과거 매물이 전부 묶여 판매자가 드러난다.
 * {@code sellerMemberId} 도 마찬가지다 — 양방향 익명 거래라 판매자·구매자는 서로를 알 수 없다.
 * 내부에 남기는 이유는 정산·CS·이중양도 추적에 필요해서지, 내보내기 위함이 아니다.
 *
 * <p>{@link #concert} · {@link #section} · {@link #faceValue} 는 티켓에서 복사한 비정규화 값이다.
 * 셋 다 티켓이 만들어진 뒤 바뀌지 않아 정합성 위험이 없다. 성능 때문이 아니라 <b>노출 경계를
 * 스키마로 긋기 위해</b> 둔다 — 매물 조회가 {@code ticket} 과 {@code seat} 를 아예 경유하지 않게 되어
 * 좌석번호 유출 경로가 원천 차단된다. 조인해 두고 DTO 에서 필드를 빼는 방식은 쓰지 않는다.
 * 나중에 필드를 추가하다 새어 나간다.
 *
 * <p>정가 기준은 현재 구역 가격({@link Section#getPrice()})이 아니라 {@link #faceValue} 다.
 * 구역 가격이 나중에 바뀌어도 그 티켓의 기준은 예매 당시 정가여야 한다.
 *
 * <p>상태 전이는 엔티티 메서드가 아니라 {@code TicketListingRepository} 의 조건부 UPDATE 로만 한다.
 * 이유는 그쪽 주석을 본다.
 *
 * <p><b>ticket 테이블에 FK 를 걸지 않는다.</b> 이 프로젝트의 기존 테이블이 모두 FK 없이 컬럼만 두는
 * 방식이라 맞춘다. 티켓 도메인 엔티티가 아직 없기도 하다.
 */
@Getter
@Entity
@Table(name = "ticket_listing",
        indexes = {
                // 콘서트별 매물을 낮은 가격순으로 읽는 경로. 없으면 매물이 늘수록 목록이 풀스캔이 된다.
                @Index(name = "idx_listing_concert_status_price",
                        columnList = "concert_id, status, price"),
                // 내 판매 내역.
                @Index(name = "idx_listing_seller_status",
                        columnList = "seller_member_id, status"),
                // 재양도 이력. 한 티켓이 여러 번 등록될 수 있다.
                @Index(name = "idx_listing_ticket", columnList = "ticket_id")})
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class TicketListing extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "listing_id")
    private Long id;

    /**
     * 양도 대상 티켓.
     *
     * <p>티켓 도메인 엔티티가 아직 없어 식별자만 들고 있다. FK 를 걸지 않는 방침이라 엔티티가
     * 생긴 뒤에도 굳이 연관관계로 바꿀 필요는 없다. <b>응답에 실으면 안 되는 값이다.</b>
     */
    @Column(name = "ticket_id", nullable = false)
    private Long ticketId;

    /**
     * 판매자.
     *
     * <p>요청자가 판매자인지 비교하는 데에만 쓴다. 조회할 일이 없어 연관관계로 걸지 않았다
     * ({@code Seat.heldByMemberId} 와 같은 이유다). <b>응답에 실으면 안 되는 값이다.</b>
     */
    @Column(name = "seller_member_id", nullable = false)
    private Long sellerMemberId;

    /** 티켓에서 복사한 공연. 콘서트별 매물 집계와 목록 표기에 쓴다. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "concert_id", nullable = false)
    private Concert concert;

    /**
     * 티켓 좌석이 속한 구역.
     *
     * <p>체결 전에 공개하는 범위가 여기까지다. 구역명·등급까지만 보여 주고 좌석번호는 내리지 않는다.
     * {@code seat} 를 거치지 않으려고 좌석이 아니라 구역을 들고 있다.
     */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "section_id", nullable = false)
    private Section section;

    /** 등록가. {@link #faceValue} 이하만 허용한다. 등록 후 바뀌지 않는다. */
    @Column(name = "price", nullable = false)
    private int price;

    /** 티켓에서 복사한 예매 시점 정가 스냅샷. 정가 이하 판정과 할인율 표기의 기준이다. */
    @Column(name = "face_value", nullable = false)
    private int faceValue;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false, length = 20)
    private ListingStatus status;

    /**
     * 등록 시각.
     *
     * <p>{@code createdAt} 과 값이 같아 보이지만 성격이 다르다. 그쪽은 감사 필드고 이쪽은 도메인 값이다.
     * 정렬·표기에는 이 값을 쓴다.
     */
    @Column(name = "listed_at", nullable = false)
    private LocalDateTime listedAt;

    /** 체결 또는 취소 시각. {@link ListingStatus#LISTED} 인 동안은 비어 있다. */
    @Column(name = "closed_at")
    private LocalDateTime closedAt;

    @Builder(access = AccessLevel.PRIVATE)
    private TicketListing(Long ticketId,
                          Long sellerMemberId,
                          Concert concert,
                          Section section,
                          int price,
                          int faceValue,
                          LocalDateTime listedAt) {
        this.ticketId = ticketId;
        this.sellerMemberId = sellerMemberId;
        this.concert = concert;
        this.section = section;
        this.price = price;
        this.faceValue = faceValue;
        this.status = ListingStatus.LISTED;
        this.listedAt = listedAt;
    }

    /**
     * 매물을 연다. 생성 시점의 상태는 언제나 {@link ListingStatus#LISTED} 라 외부에서 정하지 않는다.
     *
     * <p>등록가가 정가 이하인지는 여기서 보지 않는다. 규칙 위반은 화면에 보여 줄 말이 있는
     * 비즈니스 예외({@code ListPriceExceedsFacePriceException})라 서비스가 판단한다.
     */
    public static TicketListing open(Long ticketId,
                                     Long sellerMemberId,
                                     Concert concert,
                                     Section section,
                                     int price,
                                     int faceValue,
                                     LocalDateTime listedAt) {
        return TicketListing.builder()
                .ticketId(ticketId)
                .sellerMemberId(sellerMemberId)
                .concert(concert)
                .section(section)
                .price(price)
                .faceValue(faceValue)
                .listedAt(listedAt)
                .build();
    }

    /**
     * 지금 구매 가능한 상태인지.
     *
     * <p><b>상태 전이 앞의 선검사로 쓰면 안 된다.</b> 여기서 확인하고 상태를 바꾸면 확인과 전이
     * 사이에 다른 요청이 끼어들어 둘 다 통과한다. 전이는 언제나
     * {@code TicketListingRepository} 의 조건부 UPDATE 로만 하고, 이 메서드는 조회 응답을 만들 때만 쓴다.
     */
    public boolean isListed() {
        return status == ListingStatus.LISTED;
    }

    /** 이 회원이 이 매물의 판매자인지. 취소 권한 판정에 쓴다. */
    public boolean isSeller(Long memberId) {
        return sellerMemberId.equals(memberId);
    }

    /**
     * 정가 대비 할인율(%). 내림한다.
     *
     * <p>화면이 계산해도 되는 값이지만 서버가 준다. 목록 정렬·표기가 클라이언트마다 갈리면
     * 같은 매물이 기기에 따라 다른 할인율로 보인다.
     */
    public int discountRate() {
        if (faceValue <= 0) {
            return 0;
        }
        return (int) ((faceValue - (long) price) * 100L / faceValue);
    }
}
