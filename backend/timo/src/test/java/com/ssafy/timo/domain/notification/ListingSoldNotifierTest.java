package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.ListingSoldNotifier;
import com.ssafy.timo.domain.notification.service.NotificationBatchCreatedEvent;
import com.ssafy.timo.domain.notification.service.NotificationMessages;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.event.ApplicationEvents;
import org.springframework.test.context.event.RecordApplicationEvents;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 양도 판매 완료 알림의 정의를 확인한다. 이 알림은 아직 내보내는 곳이 없어서, 나중에 붙는 쪽이 부를 진입점이
 * 지금 그대로 쓸 수 있는 모양인지를 본다.
 *
 * <p>알림 종류와 이동 화면 컬럼이 문자열로 저장되는지도 함께 본다. 이 컬럼이 DB 의 enum 이면 새 종류를 저장할 때
 * 값이 조용히 비어 알림함 조회가 깨진다.
 */
@IntegrationTest
@RecordApplicationEvents
class ListingSoldNotifierTest {

    @Autowired
    private ListingSoldNotifier notifier;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private MockMvc mvc;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private ApplicationEvents events;

    @AfterEach
    void clearAuthentication() {
        Authenticated.clear();
    }

    @Test
    @DisplayName("판매자에게 거래 상세로 이동하는 알림이 규약대로 저장된다")
    void notifySold_savesNotificationWithContractFields() {
        Member seller = member();

        boolean recorded = notifier.notifySold(seller.getId(), 55L, "로이킴 콘서트");

        assertThat(recorded).isTrue();
        Map<String, Object> row = jdbc.queryForMap(
                "select body, type, link_type, link_id, dedup_key from notification where member_id = ?",
                seller.getId());
        assertThat(row.get("body")).isEqualTo("로이킴 콘서트 티켓이 판매됐어요");
        assertThat(row.get("type")).isEqualTo("LISTING_SOLD");
        assertThat(row.get("link_type")).isEqualTo("TRADE");
        assertThat(((Number) row.get("link_id")).longValue()).isEqualTo(55L);
        assertThat(row.get("dedup_key")).isEqualTo("LISTING_SOLD:trade=55");
    }

    @Test
    @DisplayName("같은 거래로 다시 불러도 알림은 한 번이고 푸시 이벤트도 다시 나가지 않는다")
    void notifySold_sameTradeTwice_isRecordedOnce() {
        Member seller = member();

        boolean first = notifier.notifySold(seller.getId(), 55L, "공연");
        boolean again = notifier.notifySold(seller.getId(), 55L, "공연");

        assertThat(first).isTrue();
        assertThat(again).isFalse();
        assertThat(count(seller)).isEqualTo(1);
        assertThat(events.stream(NotificationBatchCreatedEvent.class)).hasSize(1);
    }

    @Test
    @DisplayName("다른 거래는 각자 알림이 나간다")
    void notifySold_differentTrades_areSeparateNotifications() {
        Member seller = member();

        notifier.notifySold(seller.getId(), 55L, "공연");
        notifier.notifySold(seller.getId(), 56L, "공연");

        assertThat(count(seller)).isEqualTo(2);
    }

    @Test
    @DisplayName("푸시 이벤트에는 판매 완료 종류와 거래로 가는 이동 정보가 실린다")
    void notifySold_publishesEventForPush() {
        Member seller = member();

        notifier.notifySold(seller.getId(), 55L, "공연");

        assertThat(events.stream(NotificationBatchCreatedEvent.class).flatMap(e -> e.notifications().stream()))
                .singleElement().satisfies(created -> {
                    assertThat(created.type()).isEqualTo(NotificationType.LISTING_SOLD);
                    assertThat(created.linkType()).isEqualTo(LinkType.TRADE);
                    assertThat(created.linkId()).isEqualTo(55L);
                    assertThat(created.memberId()).isEqualTo(seller.getId());
                });
    }

    @Test
    @DisplayName("알림함 조회가 판매 완료 알림을 정상적으로 읽어 내려 준다")
    void inbox_returnsListingSoldNotification() throws Exception {
        Member seller = member();
        notifier.notifySold(seller.getId(), 55L, "공연");

        Authenticated.set(seller.getId());
        mvc.perform(get("/api/v1/notifications"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].type").value("LISTING_SOLD"))
                .andExpect(jsonPath("$.items[0].linkType").value("TRADE"))
                .andExpect(jsonPath("$.items[0].linkId").value(55))
                .andExpect(jsonPath("$.items[0].body").value("공연 티켓이 판매됐어요"));
    }

    @Test
    @DisplayName("알림 종류와 이동 화면 컬럼은 enum 이 아니라 VARCHAR 다")
    void typeColumns_areVarcharNotEnum() {
        List<Map<String, Object>> columns = jdbc.queryForList("""
                select column_name, column_type from information_schema.columns
                 where table_schema = database() and table_name = 'notification'
                   and column_name in ('type', 'link_type')
                """);

        assertThat(columns).extracting(c -> c.get("column_name") + ":" + c.get("column_type"))
                .containsExactlyInAnyOrder("type:varchar(40)", "link_type:varchar(20)");
    }

    @Test
    @DisplayName("판매 완료 알림의 문구는 공연명을 줄이고 구매자 정보를 담지 않는다")
    void message_clipsTitleAndCarriesOnlyTheConcert() {
        String longTitle = "가".repeat(45);

        String body = NotificationMessages.listingSold(longTitle);

        assertThat(body).isEqualTo("가".repeat(30) + "… 티켓이 판매됐어요");
    }

    @Test
    @DisplayName("거래 한 건 키 형식이 설계 문서와 같다")
    void tradeKey_matchesDesign() {
        assertThat(NotificationType.LISTING_SOLD.tradeKey(5L)).isEqualTo("LISTING_SOLD:trade=5");
        assertThat(NotificationType.LISTING_SOLD.getLinkType()).isEqualTo(LinkType.TRADE);
    }

    private long count(Member member) {
        return jdbc.queryForObject(
                "select count(*) from notification where member_id = ?", Long.class, member.getId());
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
