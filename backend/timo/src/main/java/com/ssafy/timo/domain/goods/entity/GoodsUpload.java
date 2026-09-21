package com.ssafy.timo.domain.goods.entity;

import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Index;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 굿즈 이미지 업로드 대장. 올린 key 를 한 줄씩 적어 두고, 굿즈로 이어지지 않은 <b>이미지</b>를 청소
 * 배치가 지운다 — 지우는 것은 저장소 객체이고 티켓이나 굿즈가 아니다.
 *
 * <p><b>왜 필요한가.</b> 앱은 제작 중에 이미지를 올렸다가 굿즈를 만들지 않고 그만둘 수 있다. 그때
 * 저장소에 남는 객체를 찾아낼 방법이 서버에 없다 - 굿즈 테이블에는 쓰인 key 만 있고 버려진 key 는
 * 어디에도 없기 때문이다. 대장이 그 목록이다.
 *
 * <p><b>무엇을 살릴지는 티켓 단위로 판정한다.</b> key 접두가 {@code goods/{memberId}/{ticketId}} 라 업로드가 티켓으로
 * 묶이므로, 그 티켓에 굿즈가 있으면 그 티켓의 업로드를 전부 "쓰였다" 로 친다. 굿즈의
 * {@code personLayers} 를 열어 어느 key 가 실제로 쓰였는지는 보지 않는다 - 서버가 그 JSON 구조를
 * 해석하지 않는다는 규칙을 청소 배치 때문에 깨지 않으려는 것이다. 제작 중 버리고 다시 올린 시도분이
 * 같이 살아남는 것이 이 근사의 값이고, 대신 <b>쓰고 있는 이미지를 지울 위험이 없다.</b>
 *
 * <p><b>지운 행은 남긴다.</b> 상태만 {@link GoodsUploadStatus#DELETED} 로 바꾼다. 그래야 굿즈 생성
 * 요청이 이미 지워진 key 를 가리킬 때 조회 한 번으로 알고 거절할 수 있다 - 행까지 지우면 "처음부터
 * 없던 key" 와 구분할 수 없어 깨진 굿즈가 저장된다.
 *
 * <p>회원·티켓을 연관관계가 아니라 id 로 들고 있다. 대장은 도메인 그래프의 일부가 아니라 운영용
 * 장부이고, 읽는 쪽(청소 배치)이 필요로 하는 것도 id 뿐이다.
 */
@Getter
@Entity
@Table(name = "goods_upload",
        uniqueConstraints = @UniqueConstraint(name = "uk_goods_upload_image_key", columnNames = "image_key"),
        indexes = {
                @Index(name = "idx_goods_upload_status_created", columnList = "status, created_at"),
                @Index(name = "idx_goods_upload_ticket", columnList = "ticket_id")})
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class GoodsUpload extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "goods_upload_id")
    private Long id;

    /** 올린 사람. 굿즈 제작자와 같다 - 남의 티켓으로는 올릴 수 없다. */
    @Column(name = "member_id", nullable = false)
    private Long memberId;

    /** 어느 티켓의 제작분인지. 청소가 "이 티켓에 굿즈가 있는가" 를 묻는 기준이다. */
    @Column(name = "ticket_id", nullable = false)
    private Long ticketId;

    /** 저장소 key. 유니크는 같은 key 가 두 번 적힐 일이 없다는 전제의 마지막 방어선이다. */
    @Column(name = "image_key", length = 512, nullable = false)
    private String imageKey;

    @Enumerated(EnumType.STRING)
    @Column(name = "status", length = 20, nullable = false)
    private GoodsUploadStatus status;

    /** 청소 배치가 저장소에서 지운 시각. 지우기 전에는 {@code null} 이다. */
    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    private GoodsUpload(Long memberId, Long ticketId, String imageKey) {
        this.memberId = memberId;
        this.ticketId = ticketId;
        this.imageKey = imageKey;
        this.status = GoodsUploadStatus.UPLOADED;
    }

    /**
     * 올릴 key 한 줄. <b>저장소에 쓰기 전에</b> 적는다 - 순서가 반대면 대장에 없는 key 가 생겨
     * 어느 배치도 찾지 못한다({@code GoodsUploadService} 주석 참고).
     */
    public static GoodsUpload of(Long memberId, Long ticketId, String imageKey) {
        return new GoodsUpload(memberId, ticketId, imageKey);
    }
}
