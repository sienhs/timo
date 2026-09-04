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

/**
 * {@link BaseEntity} 의 JPA Auditing 동작 검증.
 *
 * <p>좌석 선점 동작이 DB 종류를 타므로 임베디드 DB로 치환하지 않고 test 프로필의 MySQL 을 그대로 쓴다.
 * {@code @DataJpaTest} 는 {@code @Configuration} 을 스캔하지 않으므로 Auditing 설정을 명시적으로 import 한다.
 */
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@ActiveProfiles("test")
@Import(JpaAuditionConfig.class)
class BaseEntityTest {

    @Autowired
    private TestEntityManager em;

    @Test
    @DisplayName("저장하면 생성 시각과 수정 시각이 자동으로 채워진다")
    void persist_populatesCreatedAtAndUpdatedAt() {
        // Auditing 값은 마이크로초까지만 유지되므로 비교 기준도 같은 정밀도로 맞춘다.
        LocalDateTime before = LocalDateTime.now().truncatedTo(ChronoUnit.MICROS);

        TimeAuditTestEntity saved = em.persistFlushFind(new TimeAuditTestEntity("최초"));

        assertThat(saved.getCreatedAt()).isNotNull();
        assertThat(saved.getUpdatedAt()).isNotNull();
        assertThat(saved.getCreatedAt()).isAfterOrEqualTo(before);
        // 최초 저장 시점에는 두 값이 같다.
        assertThat(saved.getUpdatedAt()).isEqualTo(saved.getCreatedAt());
    }

    @Test
    @DisplayName("수정하면 수정 시각만 갱신되고 생성 시각은 보존된다")
    void update_touchesOnlyUpdatedAt() {
        TimeAuditTestEntity saved = em.persistFlushFind(new TimeAuditTestEntity("최초"));
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
        TimeAuditTestEntity saved = em.persistFlushFind(new TimeAuditTestEntity("최초"));
        Long id = saved.getId();
        LocalDateTime createdAt = saved.getCreatedAt();
        em.clear();

        TimeAuditTestEntity reloaded = em.find(TimeAuditTestEntity.class, id);

        assertThat(reloaded).isNotSameAs(saved);
        assertThat(reloaded.getCreatedAt()).isEqualTo(createdAt);
        assertThat(reloaded.getUpdatedAt()).isNotNull();
    }
}
