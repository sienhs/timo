package com.ssafy.timo.domain.concert.entity;

import com.ssafy.timo.global.entity.BaseEntity;
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
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 공연 이미지. 한 공연에 여러 장이 붙고, 상세 화면용과 소장품 제작용 소재가 {@link #purpose} 로 갈린다.
 *
 * <p>대표 포스터는 목록 조회에서 매번 필요하므로 조인 없이 읽도록
 * {@link Concert#getPosterImageKey()} 에 따로 둔다. 이 엔티티는 상세 화면용 이미지만 담는다.
 *
 * <p>URL 이 아니라 저장소 key 를 들고 있다. 접근 URL 로 바꾸는 것은
 * {@link com.ssafy.timo.global.storage.ImageStorage} 의 책임이다.
 *
 * <p>생성은 {@link Concert#addImage(String)}(상세)와
 * {@link Concert#addKitImage(String, ConcertImagePurpose)}(소재)를 통해서만 한다.
 */
@Getter
@Entity
@Table(name = "concert_image")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ConcertImage extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "concert_image_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "concert_id", nullable = false)
    private Concert concert;

    @Column(name = "image_key", length = 500, nullable = false)
    private String imageKey;

    /** 노출 순서. 0 부터 시작하고 <b>용도마다 따로</b> 센다. */
    @Column(name = "sort_order", nullable = false)
    private int sortOrder;

    /**
     * 상세 이미지인지 소장품 소재인지. 기존 행은 전부 {@link ConcertImagePurpose#DETAIL} 이다 -
     * 컬럼이 생기기 전에 올라간 이미지는 상세용밖에 없었다.
     */
    @Enumerated(EnumType.STRING)
    @Column(name = "purpose", length = 20, nullable = false)
    private ConcertImagePurpose purpose;

    ConcertImage(Concert concert, String imageKey, int sortOrder, ConcertImagePurpose purpose) {
        this.concert = concert;
        this.imageKey = imageKey;
        this.sortOrder = sortOrder;
        this.purpose = purpose;
    }
}
