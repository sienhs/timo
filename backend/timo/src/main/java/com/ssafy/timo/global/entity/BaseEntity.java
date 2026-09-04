package com.ssafy.timo.global.entity;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.MappedSuperclass;
import lombok.Getter;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 모든 엔티티의 공통 부모. 생성 시각과 수정 시각을 자동으로 기록한다.
 *
 * <p>값은 JPA Auditing 이 채우므로 {@link com.ssafy.timo.global.config.JpaAuditionConfig} 가
 * 컨텍스트에 등록되어 있어야 한다. 소프트 삭제까지 필요하면 {@link SoftDeletableEntity} 를 상속한다.
 */
@Getter
@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;
}
