package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.repository.PushDeviceRepository;
import com.ssafy.timo.global.firebase.PushMessage;
import com.ssafy.timo.global.firebase.PushNotificationSender;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

/**
 * 개별 도메인이 회원에게 푸시를 보낼 때 주입받는 진입점.
 *
 * <p>예: {@code memberPushNotificationService.send(memberId, reservationMessage)}.
 * 예매·결제·양도는 FCM 토큰 저장 방식이나 Firebase SDK를 알 필요가 없다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MemberPushNotificationService {

    private final PushDeviceRepository pushDeviceRepository;
    private final PushNotificationSender pushNotificationSender;

    public void send(Long memberId, PushMessage message) {
        pushDeviceRepository.findAllByMember_Id(memberId).forEach(device -> {
            try {
                pushNotificationSender.sendToToken(device.getToken(), message);
            } catch (RuntimeException e) {
                // 알림 실패가 결제·예매 같은 원래 업무 트랜잭션을 실패시키지 않도록 격리한다.
                // FCM 토큰 원문은 로그에 남기지 않는다.
                log.warn("Push delivery failed: memberId={}, deviceId={}", memberId, device.getId(), e);
            }
        });
    }
}
