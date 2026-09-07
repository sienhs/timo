package com.ssafy.timo.global.entity;

import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;

import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * {@link BaseEntity} 의 JPA Auditing 동작 검증.
 *
 * <p>좌석 선점 동작이 DB 종류를 타므로 임베디드 DB로 치환하지 않고 test 프로필의 MySQL 을 그대로 쓴다.
 * {@code @DataJpaTest} 슬라이스를 쓰면 컨텍스트가 따로 뜨므로 통합 테스트와 같은
 * {@link IntegrationTest} 설정을 공유하고, {@link EntityManager} 를 직접 주입받는다.
 */
@IntegrationTest
class BaseEntityTest {

    @Autowired
    private EntityManager em;

    @Test
    @DisplayName("저장하면 생성 시각과 수정 시각이 자동으로 채워진다")
    void persist_populatesCreatedAtAndUpdatedAt() {
        // Auditing 값은 마이크로초까지만 유지되므로 비교 기준도 같은 정밀도로 맞춘다.
        LocalDateTime before = LocalDateTime.now().truncatedTo(ChronoUnit.MICROS);

        TimeAuditTestEntity saved = persistFlushFind(new TimeAuditTestEntity("최초"));

        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
        assertThat(saved.getCreatedAt()).isAfterOrEqualTo(before);
        // 최초 저장 시점에는 두 값이 같다.
        assertThat(saved.getUpdatedAt()).isEqualTo(saved.getCreatedAt());
    }

    @Test
    @DisplayName("수정하면 수정 시각만 갱신되고 생성 시각은 보존된다")
    void update_touchesOnlyUpdatedAt() {
        TimeAuditTestEntity saved = persistFlushFind(new TimeAuditTestEntity("최초"));
        LocalDateTime createdAt = saved.getCreatedAt();
        LocalDateTime firstUpdatedAt = saved.getUpdatedAt();

        saved.rename("변경");
        em.flush();

        assertThat(saved.getCreatedAt()).isEqualTo(createdAt);
        assertThat(saved.getUpdatedAt()).isAfter(firstUpdatedAt);
    }

    @Test
    @DisplayName("채워진 시각은 DB에 실제로 반영된다")
    void auditedValues_arePersistedToDatabase() {
        TimeAuditTestEntity saved = persistFlushFind(new TimeAuditTestEntity("최초"));
        Long id = saved.getId();
        LocalDateTime createdAt = saved.getCreatedAt();
        em.clear();

        TimeAuditTestEntity reloaded = em.find(TimeAuditTestEntity.class, id);

        assertThat(reloaded).isNotSameAs(saved);
        assertThat(reloaded.getCreatedAt()).isEqualTo(createdAt);
        assertThat(reloaded.getUpdatedAt()).isNotNull();
    }

    /**
     * 저장한 뒤 DB 에 실제로 들어간 엔티티를 다시 읽어 온다.
     *
     * <p>detach 후 find 하는 것이 중요하다. Auditing 이 메모리에 채운 값은 나노초까지 있지만
     * MySQL 의 {@code datetime(6)} 은 마이크로초까지만 저장한다. 영속 인스턴스를 그대로 들고
     * 비교하면 나중에 DB 에서 읽은 값과 정밀도가 달라 어긋난다.
     */
    private TimeAuditTestEntity persistFlushFind(TimeAuditTestEntity entity) {
        em.persist(entity);
        em.flush();

        Long id = entity.getId();
        em.detach(entity);
        return em.find(TimeAuditTestEntity.class, id);
    }
}
