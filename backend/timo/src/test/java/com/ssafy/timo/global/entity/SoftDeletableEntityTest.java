package com.ssafy.timo.global.entity;

import com.ssafy.timo.global.config.JpaAuditionConfig;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.data.jpa.test.autoconfigure.DataJpaTest;
import org.springframework.boot.jdbc.test.autoconfigure.AutoConfigureTestDatabase;
import org.springframework.boot.jpa.test.autoconfigure.TestEntityManager;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

import static org.assertj.core.api.Assertions.assertThat;

/** {@link SoftDeletableEntity} 의 소프트 삭제 동작 검증. */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
@Import(JpaAuditionConfig.class)
class SoftDeletableEntityTest {

    @Autowired
    private TestEntityManager em;

    @Test
    @DisplayName("새로 저장한 엔티티는 삭제되지 않은 상태다")
    void newEntity_isNotDeleted() {
        SoftDeleteTestEntity saved = em.persistFlushFind(new SoftDeleteTestEntity("좌석A"));

        assertThat(saved.isDeleted()).isFalse();
        assertThat(saved.getDeletedAt()).isNull();
    }

    @Test
    @DisplayName("소프트 삭제하면 삭제 여부와 삭제 시각이 기록된다")
    void softDelete_marksFlagAndTimestamp() {
        SoftDeleteTestEntity saved = em.persistFlushFind(new SoftDeleteTestEntity("좌석A"));
        // Auditing 값은 마이크로초까지만 유지되므로 비교 기준도 같은 정밀도로 맞춘다.
        LocalDateTime before = LocalDateTime.now().truncatedTo(ChronoUnit.MICROS);

        saved.softDelete();
        em.flush();

        assertThat(saved.isDeleted()).isTrue();
        assertThat(saved.getDeletedAt()).isNotNull().isAfterOrEqualTo(before);
    }

    @Test
    @DisplayName("소프트 삭제된 행은 DB에서 사라지지 않고 상태만 바뀐다")
    void softDelete_keepsRowInDatabase() {
        SoftDeleteTestEntity saved = em.persistFlushFind(new SoftDeleteTestEntity("좌석A"));
        Long id = saved.getId();

        saved.softDelete();
        em.flush();
        em.clear();

        SoftDeleteTestEntity reloaded = em.find(SoftDeleteTestEntity.class, id);
        assertThat(reloaded).isNotNull();
        assertThat(reloaded.getName()).isEqualTo("좌석A");
        assertThat(reloaded.isDeleted()).isTrue();
        assertThat(reloaded.getDeletedAt()).isNotNull();
    }

    @Test
    @DisplayName("소프트 삭제는 수정 시각도 갱신한다")
    void softDelete_alsoTouchesUpdatedAt() {
        SoftDeleteTestEntity saved = em.persistFlushFind(new SoftDeleteTestEntity("좌석A"));
        LocalDateTime createdAt = saved.getCreatedAt();
        LocalDateTime firstUpdatedAt = saved.getUpdatedAt();

        saved.softDelete();
        em.flush();

        assertThat(saved.getCreatedAt()).isEqualTo(createdAt);
        assertThat(saved.getUpdatedAt()).isAfter(firstUpdatedAt);
    }

    @Test
    @DisplayName("이미 삭제된 엔티티를 다시 삭제해도 최초 삭제 시각을 유지한다")
    void softDelete_isIdempotent() {
        SoftDeleteTestEntity saved = em.persistFlushFind(new SoftDeleteTestEntity("좌석A"));
        saved.softDelete();
        LocalDateTime firstDeletedAt = saved.getDeletedAt();

        saved.softDelete();

        assertThat(saved.isDeleted()).isTrue();
        assertThat(saved.getDeletedAt()).isEqualTo(firstDeletedAt);
    }

    @Test
    @DisplayName("복구하면 삭제 여부와 삭제 시각이 초기화된다")
    void restore_clearsDeletionState() {
        SoftDeleteTestEntity saved = em.persistFlushFind(new SoftDeleteTestEntity("좌석A"));
        saved.softDelete();
        em.flush();

        saved.restore();
        em.flush();
        em.clear();

        SoftDeleteTestEntity reloaded = em.find(SoftDeleteTestEntity.class, saved.getId());
        assertThat(reloaded.isDeleted()).isFalse();
        assertThat(reloaded.getDeletedAt()).isNull();
    }
}
