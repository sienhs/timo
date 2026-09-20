package com.ssafy.timo.domain.notification.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.ssafy.timo.domain.notification.dto.PushTokenRow;
import com.ssafy.timo.domain.notification.repository.PushDeviceRepository;
import com.ssafy.timo.domain.notification.service.MemberPushNotificationService.MemberPush;
import com.ssafy.timo.domain.notification.service.MemberPushNotificationService.MemberPushResult;
import com.ssafy.timo.global.firebase.PushDelivery;
import com.ssafy.timo.global.firebase.PushMessage;
import com.ssafy.timo.global.firebase.PushNotificationSender;
import com.ssafy.timo.global.firebase.PushResult;
import com.ssafy.timo.global.firebase.PushResult.Outcome;
import com.ssafy.timo.global.firebase.PushTarget;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

/**
 * 회원 단위 단체 발송을 확인한다. 발송기와 저장소는 흉내 내고, 이 서비스가 하는 일만 본다: 회원마다 자기
 * 메시지를 기기에 붙이고, 죽은 토큰만 지우고, 어떤 실패도 호출부로 새지 않게 한다.
 */
class MemberPushNotificationServiceTest {

    private static final PushDelivery DELIVERY = PushDelivery.DEFAULT;

    private final PushDeviceRepository repository = mock(PushDeviceRepository.class);
    private final PushNotificationSender sender = mock(PushNotificationSender.class);
    private final PushDeviceCleaner cleaner = mock(PushDeviceCleaner.class);
    private final MemberPushNotificationService service =
            new MemberPushNotificationService(repository, sender, cleaner);

    @Test
    @DisplayName("회원마다 자기 메시지를 그 회원의 모든 기기에 붙여 보낸다")
    void sendToMembers_attachesEachMembersMessageToTheirDevices() {
        doReturn(List.of(row(1L, "a-phone"), row(1L, "a-tablet"), row(2L, "b-phone")))
                .when(repository).findTokenRowsByMemberIdIn(anyCollection());
        when(sender.sendEach(anyList(), any())).thenReturn(List.of(
                PushResult.sent("a-phone"), PushResult.sent("a-tablet"), PushResult.sent("b-phone")));
        PushMessage forA = new PushMessage("A 에게", Map.of("notificationId", "1"));
        PushMessage forB = new PushMessage("B 에게", Map.of("notificationId", "2"));

        service.sendToMembers(List.of(new MemberPush(1L, forA), new MemberPush(2L, forB)), DELIVERY);

        List<PushTarget> targets = sentTargets();
        assertThat(targets).extracting(PushTarget::token).containsExactly("a-phone", "a-tablet", "b-phone");
        assertThat(targets).extracting(PushTarget::message).containsExactly(forA, forA, forB);
        verify(sender).sendEach(anyList(), org.mockito.ArgumentMatchers.eq(DELIVERY));
    }

    @Test
    @DisplayName("결과에는 회원과 성공 여부, 에러 코드가 담기고 토큰은 담기지 않는다")
    void sendToMembers_resultsCarryMemberAndOutcomeOnly() {
        doReturn(List.of(row(1L, "ok"), row(2L, "down")))
                .when(repository).findTokenRowsByMemberIdIn(anyCollection());
        when(sender.sendEach(anyList(), any())).thenReturn(List.of(
                PushResult.sent("ok"), PushResult.failed("down", "UNAVAILABLE")));

        List<MemberPushResult> results = service.sendToMembers(List.of(
                new MemberPush(1L, message()), new MemberPush(2L, message())), DELIVERY);

        assertThat(results).containsExactly(
                new MemberPushResult(1L, Outcome.SENT, null),
                new MemberPushResult(2L, Outcome.FAILED, "UNAVAILABLE"));
    }

    @Test
    @DisplayName("죽은 토큰만 지우고 일시적으로 실패한 토큰은 지우지 않는다")
    void sendToMembers_deletesOnlyInvalidTokens() {
        doReturn(List.of(row(1L, "ok"), row(2L, "gone"), row(3L, "down")))
                .when(repository).findTokenRowsByMemberIdIn(anyCollection());
        when(sender.sendEach(anyList(), any())).thenReturn(List.of(
                PushResult.sent("ok"),
                PushResult.invalidToken("gone", "UNREGISTERED"),
                PushResult.failed("down", "UNAVAILABLE")));

        service.sendToMembers(List.of(
                new MemberPush(1L, message()), new MemberPush(2L, message()), new MemberPush(3L, message())),
                DELIVERY);

        verify(cleaner).deleteByTokens(List.of("gone"));
    }

    @Test
    @DisplayName("죽은 토큰이 없으면 지우는 호출 자체를 하지 않는다")
    void sendToMembers_noInvalidTokens_doesNotCallCleaner() {
        doReturn(List.of(row(1L, "ok"))).when(repository).findTokenRowsByMemberIdIn(anyCollection());
        when(sender.sendEach(anyList(), any())).thenReturn(List.of(PushResult.sent("ok")));

        service.sendToMembers(List.of(new MemberPush(1L, message())), DELIVERY);

        verifyNoInteractions(cleaner);
    }

    @Test
    @DisplayName("등록된 기기가 없으면 발송기를 부르지 않고 빈 결과다")
    void sendToMembers_noDevices_doesNotCallSender() {
        when(repository.findTokenRowsByMemberIdIn(anyCollection())).thenReturn(List.of());

        List<MemberPushResult> results = service.sendToMembers(List.of(new MemberPush(1L, message())), DELIVERY);

        assertThat(results).isEmpty();
        verifyNoInteractions(sender, cleaner);
    }

    @Test
    @DisplayName("보낼 것이 없으면 저장소도 조회하지 않는다")
    void sendToMembers_emptyInput_touchesNothing() {
        assertThat(service.sendToMembers(List.of(), DELIVERY)).isEmpty();

        verifyNoInteractions(repository, sender, cleaner);
    }

    @Test
    @DisplayName("같은 회원이 여러 번 들어 있으면 마지막 메시지 하나만 쓴다")
    void sendToMembers_duplicateMember_lastMessageWins() {
        doReturn(List.of(row(1L, "a"))).when(repository).findTokenRowsByMemberIdIn(anyCollection());
        when(sender.sendEach(anyList(), any())).thenReturn(List.of(PushResult.sent("a")));
        PushMessage first = new PushMessage("처음", Map.of());
        PushMessage last = new PushMessage("마지막", Map.of());

        service.sendToMembers(List.of(new MemberPush(1L, first), new MemberPush(1L, last)), DELIVERY);

        assertThat(sentTargets()).extracting(PushTarget::message).containsExactly(last);
    }

    @Test
    @DisplayName("발송기가 예외를 던져도 호출부로 새지 않고 모든 기기를 실패로 돌려주며 토큰은 지우지 않는다")
    void sendToMembers_senderThrows_isIsolatedAsFailure() {
        doReturn(List.of(row(1L, "a"), row(2L, "b")))
                .when(repository).findTokenRowsByMemberIdIn(anyCollection());
        when(sender.sendEach(anyList(), any())).thenThrow(new IllegalStateException("boom"));

        List<MemberPushResult> results = service.sendToMembers(List.of(
                new MemberPush(1L, message()), new MemberPush(2L, message())), DELIVERY);

        assertThat(results).extracting(MemberPushResult::outcome).containsOnly(Outcome.FAILED);
        assertThat(results).extracting(MemberPushResult::errorCode).containsOnly("SENDER_ERROR");
        verify(cleaner, never()).deleteByTokens(anyCollection());
    }

    @Test
    @DisplayName("토큰을 지우다 실패해도 발송 결과는 그대로 돌려준다")
    void sendToMembers_cleanerThrows_stillReturnsResults() {
        doReturn(List.of(row(1L, "gone"))).when(repository).findTokenRowsByMemberIdIn(anyCollection());
        when(sender.sendEach(anyList(), any())).thenReturn(List.of(PushResult.invalidToken("gone", "UNREGISTERED")));
        doThrow(new IllegalStateException("db down")).when(cleaner).deleteByTokens(anyCollection());

        List<MemberPushResult> results = service.sendToMembers(List.of(new MemberPush(1L, message())), DELIVERY);

        assertThat(results).containsExactly(new MemberPushResult(1L, Outcome.INVALID_TOKEN, "UNREGISTERED"));
    }

    private List<PushTarget> sentTargets() {
        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<PushTarget>> captor = ArgumentCaptor.forClass(List.class);
        verify(sender).sendEach(captor.capture(), any());
        return captor.getValue();
    }

    private static PushMessage message() {
        return new PushMessage("본문", Map.of());
    }

    private static PushTokenRow row(Long memberId, String token) {
        PushTokenRow row = mock(PushTokenRow.class);
        when(row.getMemberId()).thenReturn(memberId);
        when(row.getToken()).thenReturn(token);
        return row;
    }
}
