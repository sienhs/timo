package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.Notification;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import com.ssafy.timo.support.IntegrationTest;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 알림 테이블의 스키마가 설계 문서와 같은지 확인한다. 이 스키마는 운영 DB 에 손으로 적용되므로, 코드가 만드는
 * DDL 이 문서에서 벗어나면 배포 때 뒤늦게 드러난다.
 *
 * <p>가장 조심할 것은 값 목록을 DB 가 들고 있는 제약이다. 종류나 이동 화면 컬럼에 {@code CHECK} 나 네이티브
 * {@code enum} 이 생기면 알림 종류를 추가할 때 운영 DB 를 고쳐야 하고, 고치지 않으면 {@code INSERT IGNORE} 가
 * 위반을 오류 없이 삼켜 새 알림이 저장도 푸시도 되지 않고 사라진다.
 */
@IntegrationTest
class NotificationSchemaTest {

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Test
    @DisplayName("알림 테이블에는 CHECK 제약이 없다")
    void table_hasNoCheckConstraint() {
        List<String> checks = jdbc.queryForList("""
                select constraint_name from information_schema.table_constraints
                 where table_schema = database() and table_name = 'notification' and constraint_type = 'CHECK'
                """, String.class);

        assertThat(checks).isEmpty();
    }

    @Test
    @DisplayName("종류와 이동 화면 컬럼은 제약 없는 VARCHAR 다")
    void typeColumns_areUnconstrainedVarchar() {
        List<String> columns = jdbc.queryForList("""
                select concat(column_name, ':', column_type) from information_schema.columns
                 where table_schema = database() and table_name = 'notification'
                   and column_name in ('type', 'link_type')
                """, String.class);

        assertThat(columns).containsExactlyInAnyOrder("type:varchar(40)", "link_type:varchar(20)");
    }

    @Test
    @DisplayName("코드에 없는 종류의 문자열도 DB 는 거절하지 않는다 — 새 종류는 코드만 배포하면 된다")
    void databaseAcceptsFutureTypeNames() {
        Member member = member();

        int inserted = notificationRepository.insertIgnore(member.getId(), "SOME_FUTURE_TYPE", "본문", "SOME_FUTURE_LINK",
                1L, "FUTURE:1", LocalDateTime.of(2026, 9, 20, 9, 0));

        assertThat(inserted).as("제약이 있으면 INSERT IGNORE 가 조용히 0 을 돌려준다").isEqualTo(1);
    }

    @Test
    @DisplayName("엔티티는 문자열로 저장된 종류와 이동 화면을 enum 으로 읽어 준다")
    void entity_readsStoredNamesAsEnums() {
        Member member = member();
        notificationRepository.insertIgnore(member.getId(), NotificationType.LISTING_SOLD.name(), "본문",
                LinkType.TRADE.name(), 5L, "K:1", LocalDateTime.of(2026, 9, 20, 9, 0));
        notificationRepository.insertIgnore(member.getId(), NotificationType.ENTRY_OPEN.name(), "본문", null,
                null, "K:2", LocalDateTime.of(2026, 9, 20, 9, 1));

        List<Notification> stored = jdbc.queryForList(
                "select notification_id from notification where member_id = ? order by notification_id",
                Long.class, member.getId()).stream()
                .map(id -> notificationRepository.findById(id).orElseThrow()).toList();

        assertThat(stored.get(0).getType()).isEqualTo(NotificationType.LISTING_SOLD);
        assertThat(stored.get(0).getLinkType()).isEqualTo(LinkType.TRADE);
        assertThat(stored.get(1).getType()).isEqualTo(NotificationType.ENTRY_OPEN);
        assertThat(stored.get(1).getLinkType()).as("이동 화면이 없으면 null").isNull();
    }

    private Member member() {
        String suffix = UUID.randomUUID().toString().replace("-", "").substring(0, 8);
        return memberRepository.save(Member.builder()
                .phoneNumber("010" + suffix.replaceAll("[a-z]", "1"))
                .name("정희성")
                .nickname("티모" + suffix)
                .build());
    }
}
