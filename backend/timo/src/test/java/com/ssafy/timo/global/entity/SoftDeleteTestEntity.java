package com.ssafy.timo.global.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** {@link SoftDeletableEntity} 검증 전용 엔티티. 운영 코드에는 포함되지 않는다. */
@Entity
@Table(name = "test_soft_delete")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class SoftDeleteTestEntity extends SoftDeletableEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    public SoftDeleteTestEntity(String name) {
        this.name = name;
    }

    public void rename(String name) {
        this.name = name;
    }
}
