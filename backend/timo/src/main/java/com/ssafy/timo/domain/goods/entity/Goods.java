package com.ssafy.timo.domain.goods.entity;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.ticket.entity.Ticket;
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
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

/**
 * 굿즈(소장품). 입장 완료({@code USED})한 티켓 1장당 1개 만들 수 있다.
 *
 * <p>앱이 온디바이스 AI 로 이미지와 레이어를 전부 만들어 올리고, 서버는 검증·저장·조회만 한다.
 * 그래서 이미지는 저장소 <b>key</b> 로만 들고 있고 URL 변환은 {@code ImageStorage} 가 한다.
 *
 * <p><b>완성된 굿즈는 수정·삭제하지 않는다.</b> 상태를 바꾸는 메서드가 없는 것이 의도다.
 *
 * <p>JSON 컬럼({@code personLayers} 등)은 <b>문자열 그대로</b> 저장하고 돌려준다. 서버가 구조를
 * 해석하지 않는다는 규칙을 타입으로 못 박은 것이다 — 필드를 객체로 매핑하면 앱이 필드를 추가할
 * 때마다 서버가 따라 바뀌어야 한다. {@code @JdbcTypeCode(SqlTypes.JSON)} 은 컬럼을 MySQL
 * {@code json} 타입으로 만들고, 자바 타입이 {@code String} 이면 Hibernate 가 변환 없이 넣고 뺀다.
 * 유일한 예외는 {@code personLayers} 의 길이·순서 검증인데 그것은 서비스가 트리로 읽어서 본다.
 *
 * <p>{@code uk_goods_ticket} 이 "1티켓 1굿즈" 의 마지막 방어선이다. 동시 요청은 서비스의 조회로
 * 못 가르고 이 제약이 가른다. {@code uk_goods_member_client} 는 앱이 만든 멱등 키라 재시도가
 * 같은 굿즈로 모이게 한다.
 *
 * <p>{@code concertSnapshot} 은 생성 시점의 공연 정보다. 공연 제목이나 장소가 나중에 바뀌어도
 * 소장품에 찍힌 값은 그대로여야 하므로 조인이 아니라 스냅샷이다.
 */
@Getter
@Entity
@Table(name = "goods",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_goods_ticket", columnNames = "ticket_id"),
                @UniqueConstraint(name = "uk_goods_member_client",
                        columnNames = {"member_id", "client_goods_id"})},
        indexes = @Index(name = "idx_goods_member_created", columnList = "member_id, created_at"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Goods extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "goods_id")
    private Long id;

    /** 이 굿즈를 만든 티켓. 1티켓 1굿즈라 일대일이다. */
    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "ticket_id", nullable = false)
    private Ticket ticket;

    /** 제작자. 제작 시점의 티켓 소유자다 — 양도받은 티켓이면 예매자가 아니라 구매자다. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    /** 티켓에서 파생한다. 요청으로 받지 않고 서버가 채운다. */
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "concert_id", nullable = false)
    private Concert concert;

    /** 앱이 만든 멱등 키. 같은 값으로 재전송하면 저장하지 않고 기존 굿즈를 돌려준다. */
    @Column(name = "client_goods_id", length = 64, nullable = false)
    private String clientGoodsId;

    @Column(name = "background_key", length = 512, nullable = false)
    private String backgroundKey;

    @Column(name = "source_background_key", length = 512)
    private String sourceBackgroundKey;

    @Column(name = "person_composite_key", length = 512)
    private String personCompositeKey;

    @Column(name = "depth_map_key", length = 512)
    private String depthMapKey;

    @Column(name = "preview_key", length = 512)
    private String previewKey;

    @Enumerated(EnumType.STRING)
    @Column(name = "effect_type", length = 20, nullable = false)
    private GoodsEffect effectType;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "background_framing")
    private String backgroundFraming;

    /** 배열. 길이 ≤ 2, {@code layerOrder} 중복 없음만 검증하고 나머지 구조는 보지 않는다. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "person_layers", nullable = false)
    private String personLayers;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "transition_config", nullable = false)
    private String transitionConfig;

    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "render_metadata", nullable = false)
    private String renderMetadata;

    /** 서버가 생성 시점에 채우는 {@code { title, artist, date, venue }}. */
    @JdbcTypeCode(SqlTypes.JSON)
    @Column(name = "concert_snapshot", nullable = false)
    private String concertSnapshot;

    @Builder
    private Goods(Ticket ticket,
                  Member member,
                  Concert concert,
                  String clientGoodsId,
                  String backgroundKey,
                  String sourceBackgroundKey,
                  String personCompositeKey,
                  String depthMapKey,
                  String previewKey,
                  GoodsEffect effectType,
                  String backgroundFraming,
                  String personLayers,
                  String transitionConfig,
                  String renderMetadata,
                  String concertSnapshot) {
        this.ticket = ticket;
        this.member = member;
        this.concert = concert;
        this.clientGoodsId = clientGoodsId;
        this.backgroundKey = backgroundKey;
        this.sourceBackgroundKey = sourceBackgroundKey;
        this.personCompositeKey = personCompositeKey;
        this.depthMapKey = depthMapKey;
        this.previewKey = previewKey;
        this.effectType = effectType;
        this.backgroundFraming = backgroundFraming;
        this.personLayers = personLayers;
        this.transitionConfig = transitionConfig;
        this.renderMetadata = renderMetadata;
        this.concertSnapshot = concertSnapshot;
    }
}
