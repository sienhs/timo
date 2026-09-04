package com.ssafy.timo.global.entity;

import jakarta.persistence.Column;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;

import java.time.LocalDateTime;

/**
 * {@link BaseEntity} 에 소프트 삭제(삭제 여부 + 삭제 시각)를 더한 공통 부모.
 *
 * <p>실제 DELETE 대신 {@link #softDelete()} 로 플래그를 세운다. 조회 시 삭제분을 걸러내는 것은
 * 각 엔티티/리포지토리의 책임이다. (엔티티 단위로 {@code @SQLRestriction} 을 붙이거나
 * 쿼리에서 {@code deleted = false} 조건을 건다. {@code @MappedSuperclass} 에는 적용되지 않는다.)
 */
@Getter
@MappedSuperclass
public abstract class SoftDeletableEntity extends BaseEntity {

    @Column(name = "deleted", nullable = false)
    private boolean deleted = false;

    @Column(name = "deleted_at")
    private LocalDateTime deletedAt;

    /** 이미 삭제된 경우 최초 삭제 시각을 유지한다. */
    public void softDelete() {
        if (this.deleted) {
            return;
        }
        this.deleted = true;
        this.deletedAt = LocalDateTime.now();
    }

    /** 소프트 삭제를 되돌린다. */
    public void restore() {
        this.deleted = false;
        this.deletedAt = null;
    }
}
