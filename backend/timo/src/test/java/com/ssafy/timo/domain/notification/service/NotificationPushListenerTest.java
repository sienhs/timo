package com.ssafy.timo.domain.notification.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.ssafy.timo.domain.notification.dto.UnreadCountRow;
import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.repository.NotificationRepository;
import com.ssafy.timo.domain.notification.service.MemberPushNotificationService.MemberPush;
import com.ssafy.timo.domain.notification.service.MemberPushNotificationService.MemberPushResult;
import com.ssafy.timo.global.config.PushProperties;
import com.ssafy.timo.global.firebase.PushDelivery;
import com.ssafy.timo.global.firebase.PushResult.Outcome;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * 알림이 들어간 뒤 푸시가 어떤 모양으로 나가는지 확인한다. 비동기와 커밋 이후 동작은 여기서 보지 않는다.
 * 리스너를 직접 불러 "무엇을 보내는가" 만 본다. 언제 보내는가는 {@code NotificationPushAfterCommitTest} 가
 * 실제 커밋으로 확인한다.
 */
class NotificationPushListenerTest {

    private final MemberPushNotificationService pushService = mock(MemberPushNotificationService.class);
    private final NotificationRepository notificationRepository = mock(NotificationRepository.class);
    private final NotificationPushPolicy policy = new NotificationPushPolicy(
            new PushProperties(new PushProperties.Channel("entry", "general"), 2));
    private final NotificationPushListener listener =
            new NotificationPushListener(pushService, notificationRepository, policy);

    @Test
    @DisplayName("푸시 본문은 알림 본문 그대로이고 data 에 알림 id, 이동 화면, 대상 id, 안 읽은 개수가 문자열로 실린다")
    void onCreated_sendsBodyAndDataAsStrings() {
        doReturn(List.of(unread(1L, 3L))).when(notificationRepository).countUnreadByMemberIds(anyCollection());

        listener.onCreated(batch(created(101L, 1L, NotificationType.ENTRY_OPEN, "입장할 수 있어요",
                LinkType.CONCERT, 12L)));

        MemberPush push = onlyPush();
        assertThat(push.memberId()).isEqualTo(1L);
        assertThat(push.message().body()).isEqualTo("입장할 수 있어요");
        assertThat(push.message().data()).containsExactlyInAnyOrderEntriesOf(Map.of(
                "notificationId", "101",
                "linkType", "CONCERT",
                "linkId", "12",
                "unreadCount", "3"));
    }

    @Test
    @DisplayName("이동 대상이 없으면 linkId 는 빈 문자열이다")
    void onCreated_withoutLink_usesEmptyString() {
        doReturn(List.of(unread(1L, 1L))).when(notificationRepository).countUnreadByMemberIds(anyCollection());

        listener.onCreated(batch(created(102L, 1L, NotificationType.MARKET_NEW_LISTING, "매물이 올라왔어요",
                LinkType.MARKET, null)));

        assertThat(onlyPush().message().data()).containsEntry("linkType", "MARKET").containsEntry("linkId", "");
    }

    @Test
    @DisplayName("안 읽은 개수 행이 없는 회원은 0 으로 싣는다")
    void onCreated_missingUnreadRow_defaultsToZero() {
        doReturn(List.of()).when(notificationRepository).countUnreadByMemberIds(anyCollection());

        listener.onCreated(batch(created(103L, 1L, NotificationType.ENTRY_OPEN, "본문", LinkType.CONCERT, 1L)));

        assertThat(onlyPush().message().data()).containsEntry("unreadCount", "0");
    }

    @Test
    @DisplayName("여러 회원의 알림은 안 읽은 개수를 한 번에 세고 단체 발송 한 번으로 보낸다")
    void onCreated_manyMembers_countsOnceAndSendsOnce() {
        doReturn(List.of(unread(1L, 1L), unread(2L, 5L), unread(3L, 2L)))
                .when(notificationRepository).countUnreadByMemberIds(anyCollection());

        listener.onCreated(batch(
                created(1L, 1L, NotificationType.SHOW_REMINDER, "a", LinkType.CONCERT, 7L),
                created(2L, 2L, NotificationType.SHOW_REMINDER, "a", LinkType.CONCERT, 7L),
                created(3L, 3L, NotificationType.SHOW_REMINDER, "a", LinkType.CONCERT, 7L)));

        verify(notificationRepository, times(1)).countUnreadByMemberIds(anyCollection());
        List<MemberPush> pushes = sentPushes(1).get(0);
        assertThat(pushes).extracting(MemberPush::memberId).containsExactly(1L, 2L, 3L);
        assertThat(pushes).extracting(push -> push.message().data().get("unreadCount"))
                .containsExactly("1", "5", "2");
    }

    @Test
    @DisplayName("알림 종류가 다르면 종류별 전달 방식으로 나눠 보낸다")
    void onCreated_differentTypes_useEachTypesDelivery() {
        doReturn(List.of()).when(notificationRepository).countUnreadByMemberIds(anyCollection());

        listener.onCreated(batch(
                created(1L, 1L, NotificationType.ENTRY_OPEN, "입장", LinkType.CONCERT, 1L),
                created(2L, 2L, NotificationType.SHOW_REMINDER, "일정", LinkType.CONCERT, 1L)));

        ArgumentCaptor<PushDelivery> deliveries = ArgumentCaptor.forClass(PushDelivery.class);
        verify(pushService, times(2)).sendToMembers(anyList(), deliveries.capture());
        assertThat(deliveries.getAllValues()).extracting(PushDelivery::priority)
                .containsExactly(PushDelivery.Priority.HIGH, PushDelivery.Priority.NORMAL);
        assertThat(deliveries.getAllValues()).extracting(PushDelivery::channelId)
                .containsExactly("entry", "general");
    }

    @Test
    @DisplayName("같은 회원의 알림이 둘이면 나눠 보내서 나중 알림이 앞 알림을 덮어쓰지 않는다")
    void onCreated_sameMemberTwice_isSentInSeparateRounds() {
        doReturn(List.of(unread(1L, 2L))).when(notificationRepository).countUnreadByMemberIds(anyCollection());

        listener.onCreated(batch(
                created(10L, 1L, NotificationType.SHOW_REMINDER, "첫째", LinkType.CONCERT, 1L),
                created(11L, 1L, NotificationType.SHOW_REMINDER, "둘째", LinkType.CONCERT, 2L)));

        List<List<MemberPush>> rounds = sentPushes(2);
        assertThat(rounds).allSatisfy(round -> assertThat(round).hasSize(1));
        assertThat(rounds.get(0).get(0).message().body()).isEqualTo("첫째");
        assertThat(rounds.get(1).get(0).message().body()).isEqualTo("둘째");
    }

    @Test
    @DisplayName("발송 중 무엇이 터져도 예외를 밖으로 던지지 않는다 — 알림은 이미 알림함에 있다")
    void onCreated_anyFailure_isSwallowed() {
        doThrow(new IllegalStateException("db down")).when(notificationRepository)
                .countUnreadByMemberIds(anyCollection());

        listener.onCreated(batch(created(1L, 1L, NotificationType.ENTRY_OPEN, "본문", LinkType.CONCERT, 1L)));

        verify(pushService, times(0)).sendToMembers(anyList(), any());
    }

    @Test
    @DisplayName("발송 서비스가 실패 결과를 돌려줘도 예외 없이 끝난다")
    void onCreated_undeliveredResults_doNotThrow() {
        doReturn(List.of()).when(notificationRepository).countUnreadByMemberIds(anyCollection());
        when(pushService.sendToMembers(anyList(), any())).thenReturn(List.of(
                new MemberPushResult(1L, Outcome.FAILED, "UNAVAILABLE"),
                new MemberPushResult(1L, Outcome.INVALID_TOKEN, "UNREGISTERED")));

        listener.onCreated(batch(created(1L, 1L, NotificationType.ENTRY_OPEN, "본문", LinkType.CONCERT, 1L)));

        verify(pushService).sendToMembers(anyList(), any());
    }

    private MemberPush onlyPush() {
        List<List<MemberPush>> rounds = sentPushes(1);
        assertThat(rounds.get(0)).hasSize(1);
        return rounds.get(0).get(0);
    }

    private List<List<MemberPush>> sentPushes(int expectedCalls) {
        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<MemberPush>> captor = ArgumentCaptor.forClass(List.class);
        verify(pushService, times(expectedCalls)).sendToMembers(captor.capture(), any());
        return captor.getAllValues();
    }

    private static NotificationBatchCreatedEvent batch(NotificationCreatedEvent... notifications) {
        return new NotificationBatchCreatedEvent(List.of(notifications));
    }

    private static NotificationCreatedEvent created(Long id, Long memberId, NotificationType type, String body,
                                                    LinkType linkType, Long linkId) {
        return new NotificationCreatedEvent(id, memberId, type, body, linkType, linkId);
    }

    private static UnreadCountRow unread(Long memberId, Long count) {
        UnreadCountRow row = mock(UnreadCountRow.class);
        when(row.getMemberId()).thenReturn(memberId);
        when(row.getUnreadCount()).thenReturn(count);
        return row;
    }
}
