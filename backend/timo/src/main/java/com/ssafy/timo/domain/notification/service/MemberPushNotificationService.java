package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.dto.PushTokenRow;
import com.ssafy.timo.domain.notification.repository.PushDeviceRepository;
import com.ssafy.timo.global.firebase.PushDelivery;
import com.ssafy.timo.global.firebase.PushMessage;
import com.ssafy.timo.global.firebase.PushNotificationSender;
import com.ssafy.timo.global.firebase.PushResult;
import com.ssafy.timo.global.firebase.PushTarget;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 개별 도메인이 회원에게 푸시를 보낼 때 주입받는 진입점.
 *
 * <p>예: {@code memberPushNotificationService.send(memberId, reservationMessage)}.
 * 예매·결제·양도는 FCM 토큰 저장 방식이나 Firebase SDK를 알 필요가 없다.
 *
 * <p>개인용 {@link #send} 와 단체용 {@link #sendToMembers} 는 진입점이 다르다. 단체용만 죽은 토큰을
 * 지우고 재시도를 하며, 개인용은 원래 동작 그대로다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MemberPushNotificationService {

    private final PushDeviceRepository pushDeviceRepository;
    private final PushNotificationSender pushNotificationSender;
    private final PushDeviceCleaner pushDeviceCleaner;

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

    /**
     * 여러 회원에게 각자의 메시지를 한 번에 보낸다. 회원이 기기를 여러 대 가졌으면 기기마다 보낸다.
     *
     * <p>죽은 토큰은 지우고, 그 밖의 실패는 결과로만 알려 준다. 발송이 통째로 실패해도 예외를 던지지
     * 않는다. 알림은 이미 알림함에 저장돼 있으므로 푸시 실패가 호출부를 깨뜨릴 이유가 없다.
     *
     * <p>이 메서드에는 트랜잭션을 걸지 않는다. 외부 호출이 DB 커넥션을 붙잡는 것을 피하려는 것이다.
     * 한 회원에게는 메시지 하나만 보낸다. 같은 회원이 여러 번 들어 있으면 마지막 것이 쓰인다.
     *
     * @return 기기별 결과. 토큰 원문은 담지 않는다. 등록된 기기가 없는 회원은 결과가 없다
     */
    public List<MemberPushResult> sendToMembers(List<MemberPush> pushes, PushDelivery delivery) {
        if (pushes.isEmpty()) {
            return List.of();
        }
        Map<Long, PushMessage> messageByMember = new LinkedHashMap<>();
        pushes.forEach(push -> messageByMember.put(push.memberId(), push.message()));

        List<PushTokenRow> rows = pushDeviceRepository.findTokenRowsByMemberIdIn(messageByMember.keySet());
        if (rows.isEmpty()) {
            return List.of();
        }
        List<PushTarget> targets = rows.stream()
                .map(row -> new PushTarget(row.getToken(), messageByMember.get(row.getMemberId())))
                .toList();
        Map<String, Long> memberByToken = rows.stream()
                .collect(Collectors.toMap(PushTokenRow::getToken, PushTokenRow::getMemberId));

        List<PushResult> results;
        try {
            results = pushNotificationSender.sendEach(targets, delivery);
        } catch (RuntimeException e) {
            log.warn("Push batch failed: members={}, devices={}", messageByMember.size(), targets.size(), e);
            results = targets.stream().map(target -> PushResult.failed(target.token(), "SENDER_ERROR")).toList();
        }

        deleteDeadTokens(results);

        List<MemberPushResult> memberResults = results.stream()
                .map(result -> new MemberPushResult(memberByToken.get(result.token()), result.outcome(),
                        result.errorCode()))
                .toList();
        log.info("Push batch done: members={}, devices={}, sent={}, invalid={}, failed={}",
                messageByMember.size(), memberResults.size(),
                count(memberResults, PushResult.Outcome.SENT),
                count(memberResults, PushResult.Outcome.INVALID_TOKEN),
                count(memberResults, PushResult.Outcome.FAILED));
        return memberResults;
    }

    private void deleteDeadTokens(List<PushResult> results) {
        List<String> deadTokens = results.stream()
                .filter(result -> result.outcome() == PushResult.Outcome.INVALID_TOKEN)
                .map(PushResult::token)
                .toList();
        if (deadTokens.isEmpty()) {
            return;
        }
        try {
            int deleted = pushDeviceCleaner.deleteByTokens(deadTokens);
            log.info("Dead push tokens removed: requested={}, deleted={}", deadTokens.size(), deleted);
        } catch (RuntimeException e) {
            // 지우지 못해도 다음 발송에서 다시 걸러진다. 발송 결과를 잃을 이유가 없다.
            log.warn("Dead push token cleanup failed: count={}", deadTokens.size(), e);
        }
    }

    private static long count(List<MemberPushResult> results, PushResult.Outcome outcome) {
        return results.stream().filter(result -> result.outcome() == outcome).count();
    }

    /** 한 회원에게 보낼 메시지. */
    public record MemberPush(Long memberId, PushMessage message) {
    }

    /**
     * 기기 하나에 보낸 결과. 토큰은 로그에 남기지 않는 값이라 회원과 결과만 담는다.
     *
     * @param errorCode 실패했을 때 FCM 에러 코드 이름. 성공이면 null
     */
    public record MemberPushResult(Long memberId, PushResult.Outcome outcome, String errorCode) {
    }
}
