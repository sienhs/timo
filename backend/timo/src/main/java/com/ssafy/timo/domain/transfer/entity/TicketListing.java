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
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;

/**
 * 양도 매물 한 건. 매물의 생명주기는 이 테이블이 정본이다.
 *
 * <p><b>외부에 나가는 식별자는 {@code listingId} 하나뿐이다.</b> {@code ticketId} 가 응답에 실리면
 * 원 예매 건을 역추적할 수 있고, 같은 티켓의 과거 매물이 전부 묶여 판매자가 드러난다.
 * {@code sellerMemberId} 도 마찬가지다 — 양방향 익명 거래라 판매자·구매자는 서로를 알 수 없다.
 * 내부에 남기는 이유는 정산·CS·이중양도 추적에 필요해서지, 내보내기 위함이 아니다.
 *
 * <p>{@link #concert}, {@link #section}, {@link #seatNo}, {@link #seatCol}, {@link #faceValue} 는 등록
 * 시점에 복사해 오는 비정규화 값이다. 전부 예매가 확정된 뒤 바뀌지 않아 정합성 위험이 없다.
 * 덕분에 매물 조회가 {@code ticket} 과 {@code seat} 를 아예 경유하지 않는다. 목록 한 번에 티켓과
 * 예매와 좌석을 3단으로 조인하면 매물이 늘수록 그대로 비용이 된다.
 *
 * <p><b>좌석번호는 체결 전에도 공개한다</b>(2026-09-16 변경). 원래는 좌석이 특정되면 그 자리의
 * 예매자를 역추적할 수 있다고 보아 구역까지만 열었으나, 공식 마켓에서의 양도를 권장하는 플랫폼이라
 * 구매자가 자리를 보고 고를 수 있어야 한다는 판단이 앞선다. 판매자 식별자와 지갑 주소는 <b>그대로
 * 비공개다</b> - 그쪽은 익명 거래의 전제라 이번 변경과 무관하다.
 *
 * <h2>어디서 복사해 오는가</h2>
 *
 * <p>{@code Ticket} 은 누가·어느 공연·어느 좌석인지를 들고 있지 않고 {@code Ticket.reservation} 을
 * 거친다. 그래서 등록 시 출처는 이렇다.
 *
 * <ul>
 *   <li>{@link #concert} ← {@code ticket.reservation.concert}</li>
 *   <li>{@link #section} ← {@code ticket.reservation.seat.section}</li>
 *   <li>{@link #seatNo}, {@link #seatCol} ← {@code ticket.reservation.seat}</li>
 *   <li>{@link #faceValue} ← {@code ticket.reservation.concert.facePrice}</li>
 *   <li>{@link #sellerMemberId} ← {@code ticket.reservation.member} (티켓에 소유자 컬럼이 없다)</li>
 * </ul>
 *
 * <p>정가 기준은 구역 가격({@link Section#getPrice()})이 <b>아니다.</b> 예매 결제·환불이 모두
 * {@code Concert.facePrice} 로 이루어지므로({@code ReservationSettlementService}) 정가도 그 값이다.
 * 구역 가격은 좌석 레이아웃 등록에만 쓰이고 결제에는 관여하지 않는다.
 *
 * <p>그래도 복사해 스냅샷으로 두는 이유는, {@code Concert.facePrice} 가
 * {@code Concert.prepareForSale} 로 다시 채워질 수 있어 <b>매물이 열린 뒤 공연 정가가 바뀌면 그 매물의
 * 정가 초과 판정 기준까지 흔들리기</b> 때문이다. 판정 기준은 등록 시점에 고정돼야 한다.
 *
 * <p>상태 전이는 엔티티 메서드가 아니라 {@code TicketListingRepository} 의 조건부 UPDATE 로만 한다.
 * 이유는 그쪽 주석을 본다.
 *
 * <h2>한 티켓에 진행 중인 매물은 하나뿐</h2>
 *
 * <p>{@code (ticket_id)} 에 그냥 유니크를 걸면 취소·체결된 과거 매물까지 걸려 재양도가 막힌다.
 * 그래서 {@code status='LISTED'} 일 때만 값을 갖는 생성 칼럼({@link #activeTicket})을 두고 거기에
 * 유니크를 건다. MySQL 은 유니크 인덱스에서 {@code NULL} 을 중복으로 보지 않으므로 <b>열려 있는
 * 매물만</b> 유일해진다. {@code Reservation.activeSeat} · {@code SeatHold.activeSeat} 와 같은 수법이다.
 *
 * <p>이게 <b>이중 등록의 최종 방어선</b>이다. 서비스의 선검사는 흔한 경우를 친절한 메시지로 걸러낼
 * 뿐이고, 확인과 저장 사이에 다른 요청이 끼어드는 것은 DB 제약만이 막는다.
 *
 * <p><b>ticket 테이블에 FK 를 걸지 않는다.</b> 이 프로젝트의 기존 테이블이 모두 FK 없이 컬럼만 두는
 * 방식이라 맞춘다. 티켓 도메인 엔티티가 생긴 뒤에도 마찬가지다 — 연관관계로 바꾸면 매물을 읽을 때
 * 티켓이 딸려 와, 위에서 끊어 둔 {@code ticket} · {@code seat} 경유가 다시 열린다.
 */
@Getter
@Entity
@Table(name = "ticket_listing",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_listing_ticket_active",
                columnNames = "active_ticket"),
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
     * <p>{@code Ticket} 엔티티가 있지만 연관관계로 걸지 않고 식별자만 들고 있다. 이유는 클래스
     * 주석의 마지막 문단을 본다. <b>응답에 실으면 안 되는 값이다.</b>
     */
    @Column(name = "ticket_id", nullable = false)
    private Long ticketId;

    /**
     * 판매자. 등록 시점의 {@code ticket.reservation.member} 다.
     *
     * <p>요청자가 판매자인지 비교하는 데에만 쓴다. 조회할 일이 없어 연관관계로 걸지 않았다
     * ({@code Seat.heldByMemberId} 와 같은 이유다). <b>응답에 실으면 안 되는 값이다.</b>
     *
     * <p>티켓의 현재 소유자와는 다를 수 있다. 소유권의 정본은 온체인 {@code TicketNFT} 이고 DB 에는
     * 소유자 컬럼 자체가 없다 — 예매 행이 소유자를 말해 주는데, 체결해도 예매 행은 판매자 것으로
     * 남는다. 그래서 <b>이 값은 "판 사람"이지 "지금 주인"이 아니다.</b> 취소 권한 판정에만 쓴다.
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
     * <p>구역명과 등급 표기에 쓴다. {@code seat} 를 거치지 않으려고 좌석이 아니라 구역을 직접 들고
     * 있고, 좌석번호는 아래 두 값으로 따로 복사해 둔다.
     */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "section_id", nullable = false)
    private Section section;

    /**
     * 좌석 열. 예매 확정 후 바뀌지 않아 복사해 둔다.
     *
     * <p>좌석 자체를 연관관계로 걸지 않는 이유는 {@code seat} 를 경유하지 않기 위해서다. 매물 목록은
     * 이 두 값만 있으면 되고, 좌석 행을 통째로 들고 오면 공연장 배치 정보까지 딸려 온다.
     */
    @Column(name = "seat_no", nullable = false)
    private int seatNo;

    /** 좌석 번호. {@link #seatNo} 와 같은 이유로 복사해 둔다. */
    @Column(name = "seat_col", nullable = false)
    private int seatCol;

    /**
     * 등록가. {@link #faceValue} 이하만 허용한다.
     *
     * <p><b>매물이 열려 있는 동안 판매자가 바꿀 수 있다</b>(2026-09-17 추가). 이 클래스의 다른
     * 필드와 달리 가변이지만, 변경은 {@code TicketListingRepository.updatePriceIfListed} 의 조건부
     * UPDATE 로만 한다 — 상태 전이와 같은 이유다. 조회해서 {@code LISTED} 인지 확인한 뒤 바꾸면
     * 체결 직후의 매물 가격이 바뀌어 체결 기록과 어긋난다.
     *
     * <p>{@code int} 가 아니라 {@code long} 인 이유는 {@link #faceValue} 와 같다.
     */
    @Column(name = "price", nullable = false)
    private long price;

    /**
     * 등록 시점의 공연 정가({@code Concert.facePrice}) 스냅샷. 정가 이하 판정과 할인율 표기의 기준이다.
     *
     * <p>원본이 {@code BigInteger} 인데 여기서 {@code long} 으로 좁힌다. <b>단위가 아직 확정되지
     * 않았기 때문이다</b> — 컨트랙트는 wei 이고 백엔드 구역 가격은 원화 정수라, 예매 응답도
     * "결정 전까지 wei 를 그대로 싣는다"로 두고 {@code long} 을 쓰고 있다
     * ({@code ReservationDetailResponseDto}). 마켓만 {@code int} 로 두면 wei 값이 들어오는 순간
     * 등록 API 가 {@code ArithmeticException} 으로 터지므로 예매 쪽 표기에 맞춘다.
     *
     * <p>{@code long} 도 wei 를 끝까지 담지는 못한다(9.2e18 초과 불가). 단위가 wei 로 확정되면
     * {@code BigInteger} + {@code DECIMAL} 로 다시 올려야 한다.
     */
    @Column(name = "face_value", nullable = false)
    private long faceValue;

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

    /**
     * {@code status='LISTED'} 일 때만 티켓 id 를 갖는 생성 칼럼. {@code uk_listing_ticket_active} 의 재료다.
     *
     * <p>값은 DB 가 계산하므로 애플리케이션은 읽지도 쓰지도 않는다. 필드로 두는 유일한 이유는
     * 스키마 생성이 이 칼럼을 만들게 하기 위해서다({@code Reservation.activeSeat} 와 같다).
     */
    @Column(name = "active_ticket", insertable = false, updatable = false,
            columnDefinition = "BIGINT GENERATED ALWAYS AS (IF(status = 'LISTED', ticket_id, NULL)) STORED")
    private Long activeTicket;

    @Builder(access = AccessLevel.PRIVATE)
    private TicketListing(Long ticketId,
                          Long sellerMemberId,
                          Concert concert,
                          Section section,
                          int seatNo,
                          int seatCol,
                          long price,
                          long faceValue,
                          LocalDateTime listedAt) {
        this.ticketId = ticketId;
        this.sellerMemberId = sellerMemberId;
        this.concert = concert;
        this.section = section;
        this.seatNo = seatNo;
        this.seatCol = seatCol;
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
                                     int seatNo,
                                     int seatCol,
                                     long price,
                                     long faceValue,
                                     LocalDateTime listedAt) {
        return TicketListing.builder()
                .ticketId(ticketId)
                .sellerMemberId(sellerMemberId)
                .concert(concert)
                .section(section)
                .seatNo(seatNo)
                .seatCol(seatCol)
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
     *
     * <p>{@code (faceValue - price) * 100} 을 {@code long} 으로 곱하지 않는다. 금액 단위가 wei 면
     * 차액이 1e18 규모라 100 을 곱하는 순간 {@code long} 을 넘어 <b>음수 할인율</b>이 나온다.
     * 자릿수 걱정 없이 계산하려고 {@link BigDecimal} 을 거친다 — 매물 하나당 한 번이라 비용은 무시할 만하다.
     */
    public int discountRate() {
        if (faceValue <= 0) {
            return 0;
        }
        return BigDecimal.valueOf(faceValue - price)
                .multiply(BigDecimal.valueOf(100))
                .divide(BigDecimal.valueOf(faceValue), 0, RoundingMode.FLOOR)
                .intValue();
    }
}
