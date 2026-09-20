package com.ssafy.timo.domain.notification.entity;

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
import lombok.Getter;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

/**
 * 회원의 알림함에 쌓이는 알림 한 건. 푸시가 실패해도 여기 남으므로 알림함이 곧 안전망이다.
 *
 * <p><b>이 엔티티를 {@code save()} 로 저장하지 않는다.</b> 저장은
 * {@link com.ssafy.timo.domain.notification.repository.NotificationRepository#insertIgnore} 만 쓴다.
 * 중복 방지 유니크에 걸리면 JPA 는 예외를 던지고 트랜잭션을 rollback-only 로 만들어, 같은
 * 트랜잭션에 있던 결제까지 롤백된다. 이 클래스에 생성자를 열어 두지 않은 이유다.
 *
 * <p>{@code linkId} 에 외래 키를 걸지 않는다. 가리키는 대상이 공연·거래로 여러 테이블이고,
 * 대상이 지워져도 알림 기록은 남아야 하기 때문이다.
 */
@Getter
@Entity
@Table(name = "notification",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_notification_dedup",
                columnNames = {"member_id", "dedup_key"}),
        indexes = {
                // 목록 조회. notification_id 가 IDENTITY 라 이것만으로 최신순 정렬과 커서를 겸한다.
                @Index(name = "idx_notification_member", columnList = "member_id, notification_id DESC"),
                // 안 읽은 개수. 배지가 목록보다 훨씬 자주 불린다.
                @Index(name = "idx_notification_unread", columnList = "member_id, read_at"),
                // 오래된 알림을 지우는 배치. 이게 없으면 지울 것을 찾으려고 표 전체를 훑는다.
                @Index(name = "idx_notification_created", columnList = "created_at")
        })
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Notification extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "notification_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    /**
     * 필드를 enum 이 아니라 문자열로 두고 {@link #getType()} 에서만 enum 으로 바꾼다. enum 필드로 두면 어떤
     * 매핑을 써도 Hibernate 가 값의 목록을 DB 제약으로 만든다(MySQL 네이티브 {@code enum}, 혹은 {@code CHECK}).
     * 그러면 알림 종류를 추가할 때마다 운영 DB 를 고쳐야 하고, 고치지 않으면 {@code INSERT IGNORE} 가 그 제약
     * 위반을 오류 없이 삼켜 새 종류의 알림이 저장도 푸시도 되지 않고 사라진다. 문자열이면 컬럼은 설계 문서대로
     * 제약 없는 {@code VARCHAR} 다. 이 엔티티는 저장을 네이티브 쿼리로만 하므로 필드 타입이 저장에 영향을 주지 않는다.
     */
    @Column(name = "type", nullable = false, length = 40)
    private String type;

    /** 푸시 본문과 완전히 같은 문자열. 개행이 들어갈 수 있다. */
    @Column(nullable = false, length = 500)
    private String body;

    /** {@link #type} 과 같은 이유로 문자열로 둔다. 읽을 때는 {@link #getLinkType()} 이 enum 으로 바꾼다. */
    @Column(name = "link_type", length = 20)
    private String linkType;

    @Column(name = "link_id")
    private Long linkId;

    /**
     * 같은 회원에게 같은 알림이 두 번 가지 않게 하는 키. 형식은 {@link NotificationType} 이 만든다.
     * 중복 방지는 이 컬럼과 회원의 유니크 하나로 끝나며 별도의 발송 이력 테이블은 없다.
     */
    @Column(name = "dedup_key", nullable = false, length = 120)
    private String dedupKey;

    /** null 이면 안 읽음. */
    @Column(name = "read_at")
    private LocalDateTime readAt;

    public NotificationType getType() {
        return NotificationType.valueOf(type);
    }

    /** 이동 화면이 없는 알림이면 null. */
    public LinkType getLinkType() {
        return linkType == null ? null : LinkType.valueOf(linkType);
    }

    public boolean isRead() {
        return readAt != null;
    }
}
