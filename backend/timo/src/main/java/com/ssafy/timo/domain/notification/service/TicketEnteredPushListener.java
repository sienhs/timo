package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.service.MemberPushNotificationService.MemberPush;
import com.ssafy.timo.domain.notification.service.MemberPushNotificationService.MemberPushResult;
import com.ssafy.timo.domain.ticket.service.TicketEnteredEvent;
import com.ssafy.timo.global.firebase.PushDelivery;
import com.ssafy.timo.global.firebase.PushMessage;
import com.ssafy.timo.global.firebase.PushResult;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.time.Duration;
import java.util.List;
import java.util.Map;

/**
 * 게이트에서 입장 처리가 끝나면 티켓 주인의 앱에 조용한 푸시를 보낸다. 앱은 열려 있는 QR 화면의 티켓이
 * 이 티켓이면 화면을 "입장 완료" 로 바꾼다.
 *
 * <p><b>알림이 아니다.</b> 배너 없이 {@code data} 만 보내고, 알림함에 저장하지도 안 읽은 개수를 싣지도
 * 않는다. 그래서 {@link NotificationPushListener} 를 타지 않고 이벤트를 직접 받는다.
 *
 * <p>커밋 뒤에 별도 스레드({@code pushExecutor})에서 보내 게이트 응답이 푸시를 기다리지 않는다. 실패해도
 * 입장 판정은 이미 확정됐으므로 로그만 남긴다 - 앱이 몇 초마다 티켓 상태를 다시 묻기 때문에 푸시가 빠져도
 * 화면은 곧 따라온다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class TicketEnteredPushListener {

    static final String TYPE = "TICKET_ENTERED";

    /**
     * 우선순위는 높게 둬 절전 중인 기기에도 바로 닿게 한다. 유효 시간은 짧게 둔다 - 몇 분 뒤에 도착한
     * 푸시는 이미 폴링이 화면을 바꾼 뒤라 쓸모가 없다.
     */
    static final PushDelivery DELIVERY = new PushDelivery(PushDelivery.Priority.HIGH, Duration.ofMinutes(5), null);

    private final MemberPushNotificationService memberPushNotificationService;

    @Async("pushExecutor")
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onTicketEntered(TicketEnteredEvent event) {
        try {
            PushMessage message = PushMessage.silent(Map.of(
                    "type", TYPE,
                    "ticketId", String.valueOf(event.ticketId())));
            List<MemberPushResult> results = memberPushNotificationService.sendToMembers(
                    List.of(new MemberPush(event.ownerMemberId(), message)), DELIVERY);
            results.stream()
                    .filter(result -> result.outcome() != PushResult.Outcome.SENT)
                    .forEach(result -> log.warn("입장 완료 푸시 미전달: ticketId={}, memberId={}, outcome={}, errorCode={}",
                            event.ticketId(), result.memberId(), result.outcome(), result.errorCode()));
        } catch (Exception e) {
            log.error("입장 완료 푸시 발송 실패 (ticketId={}, memberId={})", event.ticketId(), event.ownerMemberId(), e);
        }
    }
}
