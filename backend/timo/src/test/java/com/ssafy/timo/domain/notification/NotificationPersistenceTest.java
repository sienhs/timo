package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import com.ssafy.timo.support.IntegrationTest;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 알림 저장과 중복 방지를 실제 MySQL 로 확인한다.
 *
 * <p>prod 는 {@code ddl-auto: validate} 라 인덱스를 검사하지 않는다. 유니크가 빠져도 앱은 뜨지만
 * 중복 방지가 통째로 사라지므로, 엔티티에서 뽑은 스키마에 인덱스가 실제로 생기는지 여기서 본다.
 */
@IntegrationTest
class NotificationPersistenceTest {

    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 20, 9, 0);

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    @DisplayName("스키마에 중복 방지 유니크와 조회 인덱스 둘이 생긴다")
    void schema_hasDedupUniqueAndTwoIndexes() {
        List<Map<String, Object>> rows = jdbc.queryForList("""
                select index_name, non_unique, seq_in_index, column_name, collation
                  from information_schema.statistics
                 where table_schema = database() and table_name = 'notification'
                 order by index_name, seq_in_index
                """);

        assertThat(columns(rows, "uk_notification_dedup")).containsExactly("member_id", "dedup_key");
        assertThat(columns(rows, "idx_notification_member")).containsExactly("member_id", "notification_id");
        assertThat(columns(rows, "idx_notification_unread")).containsExactly("member_id", "read_at");

        assertThat(rows).filteredOn(r -> "uk_notification_dedup".equals(r.get("index_name")))
                .allSatisfy(r -> assertThat(((Number) r.get("non_unique")).intValue()).isZero());
        // 목록 쿼리가 최신순이므로 notification_id 는 내림차순('D') 이어야 한다.
        assertThat(rows).filteredOn(r -> "idx_notification_member".equals(r.get("index_name"))
                        && "notification_id".equals(r.get("column_name")))
                .extracting(r -> r.get("collation")).containsExactly("D");
    }

    @Test
    @DisplayName("처음 넣으면 1, 같은 회원에게 같은 키를 다시 넣으면 0이고 행은 하나다")
    void insertIgnore_returnsOneThenZeroForSameKey() {
        Member member = member();
        String key = NotificationType.ENTRY_OPEN.concertKey(12L);

        int first = insert(member.getId(), NotificationType.ENTRY_OPEN, "본문", key);
        int second = insert(member.getId(), NotificationType.ENTRY_OPEN, "본문", key);

        assertThat(first).isEqualTo(1);
        assertThat(second).isZero();
        assertThat(count(member.getId())).isEqualTo(1);
    }

    @Test
    @DisplayName("같은 키라도 회원이 다르면 각자 받는다")
    void insertIgnore_sameKeyDifferentMember_bothInserted() {
        String key = NotificationType.ENTRY_OPEN.concertKey(12L);
        Member a = member();
        Member b = member();

        assertThat(insert(a.getId(), NotificationType.ENTRY_OPEN, "본문", key)).isEqualTo(1);
        assertThat(insert(b.getId(), NotificationType.ENTRY_OPEN, "본문", key)).isEqualTo(1);
    }

    @Test
    @DisplayName("같은 공연이라도 시점이 다르면 키가 달라 각각 들어간다")
    void insertIgnore_differentPhase_bothInserted() {
        Member member = member();
        NotificationType type = NotificationType.CONCERT_OPEN_REMINDER;

        assertThat(insert(member.getId(), type, "7일 전", type.concertKey("D7", 12L))).isEqualTo(1);
        assertThat(insert(member.getId(), type, "1일 전", type.concertKey("D1", 12L))).isEqualTo(1);
        assertThat(count(member.getId())).isEqualTo(2);
    }

    @Test
    @DisplayName("생성·수정 시각을 넘긴 값으로 채우고 읽지 않은 상태로 시작한다")
    void insertIgnore_fillsTimestampsAndStartsUnread() {
        Member member = member();
        insert(member.getId(), NotificationType.MARKET_NEW_LISTING, "본문",
                NotificationType.MARKET_NEW_LISTING.dateKey(LocalDate.of(2026, 9, 20)));

        Map<String, Object> row = jdbc.queryForMap(
                "select created_at, updated_at, read_at, link_type, link_id from notification where member_id = ?",
                member.getId());

        assertThat(row.get("created_at")).isEqualTo(NOW);
        assertThat(row.get("updated_at")).isEqualTo(NOW);
        assertThat(row.get("read_at")).isNull();
        assertThat(row.get("link_type")).isEqualTo("MARKET");
        assertThat(row.get("link_id")).isNull();
    }

    @Test
    @DisplayName("없는 회원에게 넣으면 예외 없이 0이 돌아온다 — 중복과 구별되지 않는다")
    void insertIgnore_unknownMember_returnsZeroSilently() {
        int inserted = insert(Long.MAX_VALUE, NotificationType.ENTRY_OPEN, "본문",
                NotificationType.ENTRY_OPEN.concertKey(1L));

        assertThat(inserted).isZero();
    }

    @Test
    @DisplayName("500자를 넘는 본문은 예외 없이 잘려 들어간다 — 문구 조립기가 길이를 지켜야 한다")
    void insertIgnore_overlongBody_isTruncatedSilently() {
        Member member = member();

        int inserted = insert(member.getId(), NotificationType.ENTRY_OPEN, "가".repeat(600),
                NotificationType.ENTRY_OPEN.concertKey(1L));

        String stored = jdbc.queryForObject(
                "select body from notification where member_id = ?", String.class, member.getId());
        assertThat(inserted).isEqualTo(1);
        assertThat(stored).hasSize(500);
    }

    @Test
    @DisplayName("dedup 키 형식이 설계 문서와 같다")
    void dedupKey_matchesDesign() {
        assertThat(NotificationType.ENTRY_OPEN.concertKey(12L)).isEqualTo("ENTRY_OPEN:concert=12");
        assertThat(NotificationType.CONCERT_OPEN_REMINDER.concertKey("H1", 12L))
                .isEqualTo("CONCERT_OPEN_H1:concert=12");
        assertThat(NotificationType.SHOW_REMINDER.concertKey("D0", 12L))
                .isEqualTo("SHOW_REMINDER_D0:concert=12");
        assertThat(NotificationType.MARKET_NEW_LISTING.dateKey(LocalDate.of(2026, 9, 20)))
                .isEqualTo("MARKET_NEW_LISTING:2026-09-20");
    }

    private int insert(Long memberId, NotificationType type, String body, String dedupKey) {
        LinkType linkType = type.getLinkType();
        Long linkId = linkType == LinkType.MARKET ? null : 12L;
        return notificationRepository.insertIgnore(
                memberId, type.name(), body, linkType.name(), linkId, dedupKey, NOW);
    }

    private long count(Long memberId) {
        return jdbc.queryForObject(
                "select count(*) from notification where member_id = ?", Long.class, memberId);
    }

    private static List<String> columns(List<Map<String, Object>> rows, String indexName) {
        return rows.stream()
                .filter(r -> indexName.equals(r.get("index_name")))
                .map(r -> (String) r.get("column_name"))
                .toList();
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
