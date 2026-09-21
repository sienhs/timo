package com.ssafy.timo.domain.notification;

import static org.assertj.core.api.Assertions.assertThat;
import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.matchesPattern;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * 알림함 조회·읽음 API 를 실제 MySQL 로 확인한다.
 *
 * <p>가장 위험한 것은 남의 알림에 닿는 경로다. 조회와 갱신 모두 요청자 조건이 빠지면 응답은 정상으로
 * 보이면서 남의 알림이 새므로, 회원을 둘 두고 서로의 알림이 섞이지 않는지를 본다.
 */
@IntegrationTest
class NotificationApiIntegrationTest {

    private static final String PATH = "/api/v1/notifications";
    private static final LocalDateTime NOW = LocalDateTime.of(2026, 9, 20, 9, 0);

    @Autowired
    private MockMvc mvc;

    @Autowired
    private NotificationRepository notificationRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private JdbcTemplate jdbc;

    @Autowired
    private ObjectMapper objectMapper;

    @AfterEach
    void clearAuthentication() {
        Authenticated.clear();
    }

    @Test
    @DisplayName("목록은 최신순이고 알림의 모든 필드가 응답 규약대로 나온다")
    void list_returnsNewestFirstWithContractFields() throws Exception {
        Member me = member();
        long concertNoti = insert(me, "ENTRY_OPEN:concert=12", NotificationType.ENTRY_OPEN,
                "로이킴 콘서트, 지금부터 입장할 수 있어요", LinkType.CONCERT, 12L);
        long marketNoti = insert(me, "MARKET_NEW_LISTING:2026-09-20", NotificationType.MARKET_NEW_LISTING,
                "알림 신청한 공연 2건에 양도 매물이 올라왔어요\n· 공연A\n· 공연B", LinkType.MARKET, null);

        Authenticated.set(me.getId());
        mvc.perform(get(PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(2)))
                .andExpect(jsonPath("$.items[0].notificationId").value(marketNoti))
                .andExpect(jsonPath("$.items[0].type").value("MARKET_NEW_LISTING"))
                .andExpect(jsonPath("$.items[0].body").value("알림 신청한 공연 2건에 양도 매물이 올라왔어요\n· 공연A\n· 공연B"))
                .andExpect(jsonPath("$.items[0].linkType").value("MARKET"))
                .andExpect(jsonPath("$.items[0].linkId").doesNotExist())
                .andExpect(jsonPath("$.items[0].read").value(false))
                .andExpect(jsonPath("$.items[0].createdAt")
                        .value(matchesPattern("2026-09-20T09:00(:00)?(\\.0+)?\\+09:00")))
                .andExpect(jsonPath("$.items[1].notificationId").value(concertNoti))
                .andExpect(jsonPath("$.items[1].linkType").value("CONCERT"))
                .andExpect(jsonPath("$.items[1].linkId").value(12))
                .andExpect(jsonPath("$.hasNext").value(false))
                .andExpect(jsonPath("$.nextCursor").doesNotExist());
    }

    @Test
    @DisplayName("커서로 끝까지 넘기면 중복도 누락도 없다")
    void list_cursorPaging_hasNoDuplicatesOrGaps() throws Exception {
        Member me = member();
        List<Long> inserted = new ArrayList<>();
        for (int i = 0; i < 5; i++) {
            inserted.add(insert(me, "ENTRY_OPEN:concert=" + i, NotificationType.ENTRY_OPEN, "본문" + i,
                    LinkType.CONCERT, (long) i));
        }

        Authenticated.set(me.getId());
        List<Long> seen = new ArrayList<>();
        Long cursor = null;
        int pages = 0;
        boolean hasNext = true;
        while (hasNext) {
            MvcResult result = mvc.perform(get(PATH).param("size", "2")
                            .param("cursor", cursor == null ? null : String.valueOf(cursor)))
                    .andExpect(status().isOk()).andReturn();
            JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString());
            body.get("items").forEach(n -> seen.add(n.get("notificationId").asLong()));
            hasNext = body.get("hasNext").asBoolean();
            cursor = hasNext ? body.get("nextCursor").asLong() : null;
            pages++;
        }

        List<Long> expected = new ArrayList<>(inserted);
        java.util.Collections.reverse(expected);
        assertThat(seen).containsExactlyElementsOf(expected);
        assertThat(pages).isEqualTo(3);
    }

    @Test
    @DisplayName("페이지를 넘기는 사이 새 알림이 와도 이미 본 알림이 다시 나오지 않는다")
    void list_newNotificationArrivesBetweenPages_noDuplicate() throws Exception {
        Member me = member();
        for (int i = 0; i < 3; i++) {
            insert(me, "ENTRY_OPEN:concert=" + i, NotificationType.ENTRY_OPEN, "본문" + i, LinkType.CONCERT, (long) i);
        }
        Authenticated.set(me.getId());
        MvcResult first = mvc.perform(get(PATH).param("size", "2")).andReturn();
        JsonNode firstBody = objectMapper.readTree(first.getResponse().getContentAsString());
        long cursor = firstBody.get("nextCursor").asLong();
        List<Long> firstIds = new ArrayList<>();
        firstBody.get("items").forEach(n -> firstIds.add(n.get("notificationId").asLong()));

        insert(me, "ENTRY_OPEN:concert=99", NotificationType.ENTRY_OPEN, "새 알림", LinkType.CONCERT, 99L);

        MvcResult second = mvc.perform(get(PATH).param("size", "2").param("cursor", String.valueOf(cursor)))
                .andReturn();
        JsonNode secondBody = objectMapper.readTree(second.getResponse().getContentAsString());
        List<Long> secondIds = new ArrayList<>();
        secondBody.get("items").forEach(n -> secondIds.add(n.get("notificationId").asLong()));

        assertThat(secondIds).doesNotContainAnyElementsOf(firstIds).hasSize(1);
    }

    @Test
    @DisplayName("목록과 개수에 남의 알림이 섞이지 않는다")
    void list_andCount_excludeOthersNotifications() throws Exception {
        Member me = member();
        Member other = member();
        insert(me, "ENTRY_OPEN:concert=1", NotificationType.ENTRY_OPEN, "내 알림", LinkType.CONCERT, 1L);
        insert(other, "ENTRY_OPEN:concert=1", NotificationType.ENTRY_OPEN, "남의 알림 1", LinkType.CONCERT, 1L);
        insert(other, "ENTRY_OPEN:concert=2", NotificationType.ENTRY_OPEN, "남의 알림 2", LinkType.CONCERT, 2L);

        Authenticated.set(me.getId());
        mvc.perform(get(PATH))
                .andExpect(jsonPath("$.items", hasSize(1)))
                .andExpect(jsonPath("$.items[0].body").value("내 알림"));
        mvc.perform(get(PATH + "/unread-count"))
                .andExpect(jsonPath("$.unreadCount").value(1));
    }

    @Test
    @DisplayName("안 읽은 개수는 읽음 처리하면 줄어든다")
    void unreadCount_decreasesAfterMarkRead() throws Exception {
        Member me = member();
        long first = insert(me, "ENTRY_OPEN:concert=1", NotificationType.ENTRY_OPEN, "a", LinkType.CONCERT, 1L);
        insert(me, "ENTRY_OPEN:concert=2", NotificationType.ENTRY_OPEN, "b", LinkType.CONCERT, 2L);

        Authenticated.set(me.getId());
        mvc.perform(get(PATH + "/unread-count")).andExpect(jsonPath("$.unreadCount").value(2));
        mvc.perform(patch(PATH + "/" + first + "/read")).andExpect(status().isNoContent());

        mvc.perform(get(PATH + "/unread-count")).andExpect(jsonPath("$.unreadCount").value(1));
        mvc.perform(get(PATH)).andExpect(jsonPath("$.items[1].read").value(true))
                .andExpect(jsonPath("$.items[0].read").value(false));
    }

    @Test
    @DisplayName("알림이 없으면 개수는 0이고 목록은 비어 있다")
    void emptyInbox_returnsZeroAndEmptyList() throws Exception {
        Member me = member();

        Authenticated.set(me.getId());
        mvc.perform(get(PATH + "/unread-count")).andExpect(jsonPath("$.unreadCount").value(0));
        mvc.perform(get(PATH))
                .andExpect(jsonPath("$.items", hasSize(0)))
                .andExpect(jsonPath("$.hasNext").value(false));
    }

    @Test
    @DisplayName("이미 읽은 알림을 다시 읽음 처리해도 204 이고 읽은 시각은 처음 값이다")
    void markRead_isIdempotentAndKeepsFirstReadAt() throws Exception {
        Member me = member();
        long id = insert(me, "ENTRY_OPEN:concert=1", NotificationType.ENTRY_OPEN, "a", LinkType.CONCERT, 1L);

        Authenticated.set(me.getId());
        mvc.perform(patch(PATH + "/" + id + "/read")).andExpect(status().isNoContent());
        Object firstReadAt = readAt(id);
        mvc.perform(patch(PATH + "/" + id + "/read")).andExpect(status().isNoContent());

        assertThat(firstReadAt).isNotNull();
        assertThat(readAt(id)).isEqualTo(firstReadAt);
    }

    @Test
    @DisplayName("남의 알림을 읽음 처리하면 404 이고 그 알림은 그대로 안 읽음이다")
    void markRead_othersNotification_is404AndUntouched() throws Exception {
        Member me = member();
        Member owner = member();
        long id = insert(owner, "ENTRY_OPEN:concert=1", NotificationType.ENTRY_OPEN, "a", LinkType.CONCERT, 1L);

        Authenticated.set(me.getId());
        mvc.perform(patch(PATH + "/" + id + "/read")).andExpect(status().isNotFound());

        assertThat(readAt(id)).isNull();
    }

    @Test
    @DisplayName("없는 알림을 읽음 처리해도 남의 알림과 같은 404 다")
    void markRead_unknownNotification_is404() throws Exception {
        Member me = member();

        Authenticated.set(me.getId());
        mvc.perform(patch(PATH + "/" + Long.MAX_VALUE + "/read")).andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("전체 읽음 처리하면 내 안 읽은 알림이 모두 읽음이 되고 개수는 0 이 된다")
    void markAllRead_marksEveryUnreadNotificationOfMine() throws Exception {
        Member me = member();
        insert(me, "ENTRY_OPEN:concert=1", NotificationType.ENTRY_OPEN, "a", LinkType.CONCERT, 1L);
        insert(me, "ENTRY_OPEN:concert=2", NotificationType.ENTRY_OPEN, "b", LinkType.CONCERT, 2L);

        Authenticated.set(me.getId());
        mvc.perform(patch(PATH + "/read-all")).andExpect(status().isNoContent());

        mvc.perform(get(PATH + "/unread-count")).andExpect(jsonPath("$.unreadCount").value(0));
        mvc.perform(get(PATH))
                .andExpect(jsonPath("$.items[0].read").value(true))
                .andExpect(jsonPath("$.items[1].read").value(true));
    }

    @Test
    @DisplayName("전체 읽음 처리는 남의 알림을 건드리지 않는다")
    void markAllRead_doesNotTouchOthersNotifications() throws Exception {
        Member me = member();
        Member other = member();
        long othersId = insert(other, "ENTRY_OPEN:concert=1", NotificationType.ENTRY_OPEN, "남의 알림",
                LinkType.CONCERT, 1L);
        insert(me, "ENTRY_OPEN:concert=2", NotificationType.ENTRY_OPEN, "내 알림", LinkType.CONCERT, 2L);

        Authenticated.set(me.getId());
        mvc.perform(patch(PATH + "/read-all")).andExpect(status().isNoContent());

        assertThat(readAt(othersId)).isNull();
    }

    @Test
    @DisplayName("이미 읽은 알림은 전체 읽음 처리해도 읽은 시각이 그대로다")
    void markAllRead_keepsAlreadyReadTimestamps() throws Exception {
        Member me = member();
        long alreadyRead = insert(me, "ENTRY_OPEN:concert=1", NotificationType.ENTRY_OPEN, "a",
                LinkType.CONCERT, 1L);
        insert(me, "ENTRY_OPEN:concert=2", NotificationType.ENTRY_OPEN, "b", LinkType.CONCERT, 2L);

        Authenticated.set(me.getId());
        mvc.perform(patch(PATH + "/" + alreadyRead + "/read")).andExpect(status().isNoContent());
        Object firstReadAt = readAt(alreadyRead);

        mvc.perform(patch(PATH + "/read-all")).andExpect(status().isNoContent());

        assertThat(readAt(alreadyRead)).isEqualTo(firstReadAt);
    }

    @Test
    @DisplayName("알림이 없어도 전체 읽음 처리는 204 다")
    void markAllRead_emptyInbox_is204() throws Exception {
        Member me = member();

        Authenticated.set(me.getId());
        mvc.perform(patch(PATH + "/read-all")).andExpect(status().isNoContent());
    }

    @Test
    @DisplayName("size 나 cursor 가 범위를 벗어나거나 형식이 틀리면 400 이다")
    void list_invalidParams_are400() throws Exception {
        Member me = member();

        Authenticated.set(me.getId());
        mvc.perform(get(PATH).param("size", "0")).andExpect(status().isBadRequest());
        mvc.perform(get(PATH).param("size", "51")).andExpect(status().isBadRequest());
        mvc.perform(get(PATH).param("cursor", "0")).andExpect(status().isBadRequest());
        mvc.perform(get(PATH).param("cursor", "abc")).andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("size 를 주지 않으면 20건, 50건까지는 허용된다")
    void list_sizeDefaultsToTwentyAndAllowsFifty() throws Exception {
        Member me = member();
        for (int i = 0; i < 25; i++) {
            insert(me, "ENTRY_OPEN:concert=" + i, NotificationType.ENTRY_OPEN, "n" + i, LinkType.CONCERT, (long) i);
        }

        Authenticated.set(me.getId());
        mvc.perform(get(PATH))
                .andExpect(jsonPath("$.items", hasSize(20)))
                .andExpect(jsonPath("$.hasNext").value(true));
        mvc.perform(get(PATH).param("size", "50"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items", hasSize(25)))
                .andExpect(jsonPath("$.hasNext").value(false));
    }

    private long insert(Member member, String dedupKey, NotificationType type, String body, LinkType linkType,
                        Long linkId) {
        notificationRepository.insertIgnore(
                member.getId(), type.name(), body, linkType.name(), linkId, dedupKey, NOW);
        return notificationRepository.findIdByMemberIdAndDedupKey(member.getId(), dedupKey).orElseThrow();
    }

    private Object readAt(long notificationId) {
        return jdbc.queryForMap("select read_at from notification where notification_id = ?", notificationId)
                .get("read_at");
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
