package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.service.MemberPushNotificationService.MemberPush;
import com.ssafy.timo.domain.ticket.service.TicketEnteredEvent;
import com.ssafy.timo.global.firebase.PushDelivery;
import com.ssafy.timo.global.firebase.PushMessage;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigInteger;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;

@ExtendWith(MockitoExtension.class)
class TicketEnteredPushListenerTest {

    @Mock
    private MemberPushNotificationService memberPushNotificationService;

    @InjectMocks
    private TicketEnteredPushListener listener;

    @Test
    @DisplayName("티켓 주인에게 본문 없이 type 과 문자열 ticketId 만 담아 높은 우선순위로 보낸다")
    void sendsSilentPushToOwner() {
        listener.onTicketEntered(new TicketEnteredEvent(123L, BigInteger.TEN, 7L));

        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<MemberPush>> pushes = ArgumentCaptor.forClass(List.class);
        ArgumentCaptor<PushDelivery> delivery = ArgumentCaptor.forClass(PushDelivery.class);
        then(memberPushNotificationService).should().sendToMembers(pushes.capture(), delivery.capture());

        assertThat(pushes.getValue()).hasSize(1);
        MemberPush push = pushes.getValue().get(0);
        assertThat(push.memberId()).isEqualTo(7L);
        PushMessage message = push.message();
        assertThat(message.isSilent()).isTrue();
        assertThat(message.data()).isEqualTo(Map.of("type", "TICKET_ENTERED", "ticketId", "123"));
        assertThat(delivery.getValue().priority()).isEqualTo(PushDelivery.Priority.HIGH);
    }

    @Test
    @DisplayName("발송이 터져도 예외를 밖으로 던지지 않는다 - 입장 처리는 이미 커밋됐다")
    void swallowsSenderFailure() {
        given(memberPushNotificationService.sendToMembers(anyList(), any()))
                .willThrow(new IllegalStateException("boom"));

        assertThatCode(() -> listener.onTicketEntered(new TicketEnteredEvent(123L, BigInteger.TEN, 7L)))
                .doesNotThrowAnyException();
    }
}
