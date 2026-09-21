package com.ssafy.timo.domain.concert.entity;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OneToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;

/**
 * 공연. 어느 공연장에서 열리는지와, 출연 아티스트·상세 이미지 목록을 함께 들고 있다.
 *
 * <p>연관관계는 모두 지연 로딩이다. 목록 조회에서 N+1 이 되지 않도록 조회 쿼리에서
 * 필요한 것만 fetch join 한다.
 *
 * <p>이미지는 URL 이 아니라 저장소 key 로 들고 있다. 접근 URL 로 바꾸는 것은
 * {@link com.ssafy.timo.global.storage.ImageStorage} 의 책임이다.
 */
@Getter
@Entity
@Table(name = "concert")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Concert extends BaseEntity {

    /** 공연 시작 이 시간 전까지만 예매(선점·결제)할 수 있다. 마감 시각은 저장하지 않고 매번 유도한다. */
    public static final int BOOKING_CUTOFF_HOURS = 2;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "concert_id")
    private Long id;

    @Column(name = "title", length = 200, nullable = false)
    private String title;

    @Enumerated(EnumType.STRING)
    @Column(name = "genre", nullable = false)
    private ConcertGenre genre;

    /** 대표 포스터. 목록·썸네일에서 매번 쓰이므로 상세 이미지와 달리 조인 없이 읽도록 여기에 둔다. */
    @Column(name = "poster_image_key", length = 500)
    private String posterImageKey;

    @Column(name = "description", columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "age_rating", nullable = false)
    private AgeRating ageRating;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", nullable = false)
    private ConcertStatus status;

    @Column(name = "view_count", nullable = false)
    private int viewCount;

    /** 공연 시작일 */
    @Column(name = "start_date")
    private LocalDateTime startDate;

    /** 공연 종료일 */
    @Column(name = "end_date")
    private LocalDateTime endDate;

    /** 예매 오픈 시각 */
    @Column(name = "open_at")
    private LocalDateTime openAt;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "venue_id", nullable = false)
    private Venue venue;

    /**
     * 이 공연을 주최하는 회원({@link com.ssafy.timo.domain.member.entity.Role#ORGANIZER}).
     * 생성 시점엔 비어 있을 수 있다 - 누가 주최하는지는 온체인 판매 준비 단계({@link #prepareForSale})에서
     * 정해진다. 예매를 열려면 이 값과 온체인 {@link #showId}가 채워져 있어야 한다.
     *
     * <p>정가는 더 이상 여기 없다 - 공연이 아니라 {@link com.ssafy.timo.domain.seat.entity.Section}이
     * 구역마다 다른 가격을 갖고, {@code ShowRegistry.registerShow}에는 구역 5개의 가격을 배열로 실어
     * 올린다({@code ShowRegistryClient.registerShow} 참고).
     */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "organizer_id")
    private Member organizer;

    /** {@code ShowRegistry}의 showId. 온체인 등록 전엔 null이다({@link #confirmRegistered}). */
    @Column(name = "show_id")
    private BigInteger showId;

    @OneToMany(mappedBy = "concert", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<ConcertArtist> concertArtists = new ArrayList<>();

    @OneToMany(mappedBy = "concert", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC")
    private List<ConcertImage> images = new ArrayList<>();

    /**
     * 생성 시점의 상태와 조회수는 외부에서 정하지 않는다.
     * 갓 등록된 공연은 항상 예매 전({@link ConcertStatus#SCHEDULED})이고 조회수는 0 이다.
     *
     * <p>출연 아티스트와 상세 이미지는 {@link #addArtist(Artist)}, {@link #addImage(String)} 로 붙인다.
     */
    @Builder
    public Concert(String title,
                   ConcertGenre genre,
                   String posterImageKey,
                   String description,
                   AgeRating ageRating,
                   LocalDateTime startDate,
                   LocalDateTime endDate,
                   LocalDateTime openAt,
                   Venue venue) {
        this.title = title;
        this.genre = genre;
        this.posterImageKey = posterImageKey;
        this.description = description;
        this.ageRating = ageRating;
        this.status = ConcertStatus.SCHEDULED;
        this.viewCount = 0;
        this.startDate = startDate;
        this.endDate = endDate;
        this.openAt = openAt;
        this.venue = venue;
    }

    /** 주최자를 정해 온체인 판매 준비를 시작한다. {@link #confirmRegistered}가 뒤따라야 실제로 예매를 열 수 있다. */
    public void prepareForSale(Member organizer) {
        this.organizer = organizer;
    }

    /** {@code ShowRegistry.registerShow} 트랜잭션이 확정된 뒤, 발급된 showId를 채운다. */
    public void confirmRegistered(BigInteger showId) {
        this.showId = showId;
    }

    /** 예매(민팅)를 열 수 있는 상태인지 - 주최자·온체인 showId가 모두 갖춰졌는지. */
    public boolean isReadyForBooking() {
        return organizer != null && showId != null;
    }

    /**
     * 지금 이 공연을 예매(선점·결제)할 수 있는지, 아니라면 어떤 사유인지.
     *
     * <p>{@link #isReadyForBooking()}과는 역할이 다르다 - 그쪽은 주최자·온체인 showId가 갖춰져
     * "예매를 열 수 있는 상태로 등록됐는지"(등록 시점 한 번)를 보고, 이건 지금 이 순간이 예매 가능한
     * 시간 창(오픈 시각 ~ 공연 시작 {@value #BOOKING_CUTOFF_HOURS}시간 전) 안에 있는지(요청마다 매번)를
     * 본다. 값이 비어 있으면 예매할 수 있다는 뜻이다.
     *
     * <p>판정 순서는 상태 → 오픈 전 → 마감 후다. 여러 사유가 겹치면(예: 매진인데 시간도 지남) 앞의
     * 것을 사유로 답한다. 오픈·시작 시각 중 하나라도 없으면 오픈 전으로 본다 - 언제 열리는지 모르는
     * 공연을 예매 가능으로 둘 수는 없다.
     */
    public Optional<BookingBlockReason> bookingBlockReason(LocalDateTime now) {
        if (status != ConcertStatus.ON_SALE) {
            return Optional.of(BookingBlockReason.NOT_ON_SALE);
        }
        if (openAt == null || startDate == null || now.isBefore(openAt)) {
            return Optional.of(BookingBlockReason.NOT_OPEN);
        }
        if (!now.isBefore(startDate.minusHours(BOOKING_CUTOFF_HOURS))) {
            return Optional.of(BookingBlockReason.CLOSED);
        }
        return Optional.empty();
    }

    /**
     * 예매 오픈 전인지. 상태 컬럼이 아니라 시각만 본다 - 오픈 직후 최대 1분은 컬럼이 아직
     * {@code SCHEDULED} 라도 열린 것으로 친다. 오픈 시각이 없으면 언제 열릴지 모르므로 오픈 전이다.
     */
    public boolean isBeforeOpen(LocalDateTime now) {
        return openAt == null || now.isBefore(openAt);
    }

    /** {@link #bookingBlockReason}이 비어 있는지를 boolean으로만 보고 싶을 때. */
    public boolean isBookableAt(LocalDateTime now) {
        return bookingBlockReason(now).isEmpty();
    }

    /** 출연 아티스트를 추가한다. 중복 여부는 호출 쪽에서 걸러 온다고 보고 여기서는 검사하지 않는다. */
    public void addArtist(Artist artist) {
        this.concertArtists.add(new ConcertArtist(this, artist));
    }

    /** 상세 이미지를 추가한다. 노출 순서는 추가된 순서를 그대로 따른다. */
    public void addImage(String imageKey) {
        addImage(imageKey, ConcertImagePurpose.DETAIL);
    }

    /**
     * 소장품 제작용 소재 이미지를 추가한다. 상세 이미지와 같은 표에 살고 용도로만 갈린다.
     *
     * @param purpose {@link ConcertImagePurpose#KIT_BACKGROUND} 또는
     *                {@link ConcertImagePurpose#KIT_PERSON}
     */
    public void addKitImage(String imageKey, ConcertImagePurpose purpose) {
        if (!purpose.isKit()) {
            throw new IllegalArgumentException("소재 용도가 아닙니다: " + purpose);
        }
        addImage(imageKey, purpose);
    }

    /** 순서는 <b>용도마다 따로</b> 센다 - 소재를 더해도 상세 이미지의 순서가 밀리지 않는다. */
    private void addImage(String imageKey, ConcertImagePurpose purpose) {
        int sortOrder = (int) this.images.stream()
                .filter(image -> image.getPurpose() == purpose)
                .count();
        this.images.add(new ConcertImage(this, imageKey, sortOrder, purpose));
    }

    public List<Artist> getArtists() {
        return this.concertArtists.stream()
                .map(ConcertArtist::getArtist)
                .toList();
    }

    public List<ConcertArtist> getConcertArtists() {
        return Collections.unmodifiableList(this.concertArtists);
    }

    /**
     * <b>상세 이미지만</b> 돌려준다. 소재({@link ConcertImagePurpose#isKit()})는 빠진다 - 공연 상세는
     * 인증 없이 열리는 공개 API 라 소재가 섞이면 티켓 없는 사람에게도 나간다. 소재가 필요하면
     * {@link #getKitImages(ConcertImagePurpose)} 를 쓴다.
     */
    public List<ConcertImage> getImages() {
        return this.images.stream()
                .filter(image -> image.getPurpose() == ConcertImagePurpose.DETAIL)
                .toList();
    }

    /** 그 용도의 소재를 {@code sortOrder} 순으로 돌려준다. */
    public List<ConcertImage> getKitImages(ConcertImagePurpose purpose) {
        return this.images.stream()
                .filter(image -> image.getPurpose() == purpose)
                .sorted(Comparator.comparingInt(ConcertImage::getSortOrder))
                .toList();
    }
}
