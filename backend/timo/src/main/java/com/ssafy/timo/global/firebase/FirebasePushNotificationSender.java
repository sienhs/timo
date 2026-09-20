package com.ssafy.timo.global.firebase;

import com.google.firebase.ErrorCode;
import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.AndroidNotification;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;
import com.ssafy.timo.global.config.PushProperties;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.IntStream;

/**
 * Firebase Admin SDK를 통한 실제 FCM 발송 구현.
 *
 * <p>단체 발송은 {@code sendEachForMulticast} 가 아니라 {@code sendEach} 를 쓴다. 멀티캐스트는 모든
 * 토큰에 같은 메시지를 보내는데, 푸시 {@code data} 에 실리는 알림 id 와 안 읽은 개수는 수신자마다 다르기
 * 때문이다. 한 번에 보낼 수 있는 상한(500)은 같다.
 */
@Slf4j
@Primary
@Component
@ConditionalOnProperty(prefix = "app.firebase", name = "messaging-enabled", havingValue = "true")
public class FirebasePushNotificationSender implements PushNotificationSender {

    /** FCM 이 한 번의 배치 호출에서 받는 메시지 상한. */
    static final int MAX_BATCH_SIZE = 500;

    /** 첫 재시도 전 대기. 이후 두 배씩 늘어난다. */
    static final long BACKOFF_BASE_MILLIS = 500L;

    private final FirebaseMessaging messaging;
    private final int maxRetries;
    private final Sleeper sleeper;

    @Autowired
    public FirebasePushNotificationSender(FirebaseApp firebaseApp, PushProperties properties) {
        this(FirebaseMessaging.getInstance(firebaseApp), properties.retry(), Thread::sleep);
    }

    /** 테스트가 SDK 와 대기 시간을 갈아끼우려고 연 생성자. */
    FirebasePushNotificationSender(FirebaseMessaging messaging, int maxRetries, Sleeper sleeper) {
        this.messaging = messaging;
        this.maxRetries = Math.max(0, maxRetries);
        this.sleeper = sleeper;
    }

    @Override
    public String sendToToken(String token, PushMessage message) {
        return send(toMessage(token, message, PushDelivery.DEFAULT));
    }

    @Override
    public String sendToTopic(String topic, PushMessage message) {
        return send(baseMessage(message, PushDelivery.DEFAULT).setTopic(topic).build());
    }

    @Override
    public List<PushResult> sendEach(List<PushTarget> targets, PushDelivery delivery) {
        List<PushResult> results = new ArrayList<>(targets.size());
        for (int from = 0; from < targets.size(); from += MAX_BATCH_SIZE) {
            List<PushTarget> chunk = targets.subList(from, Math.min(from + MAX_BATCH_SIZE, targets.size()));
            results.addAll(sendChunk(chunk, delivery));
        }
        return guardAgainstPayloadError(results);
    }

    /**
     * 한 묶음을 보내고, 일시적으로 실패한 것만 골라 다시 보낸다. 다시 보낼 때 성공한 토큰까지 함께 보내면
     * 같은 알림이 기기에 두 번 뜬다.
     */
    private List<PushResult> sendChunk(List<PushTarget> chunk, PushDelivery delivery) {
        PushResult[] resolved = new PushResult[chunk.size()];
        List<Integer> pending = new ArrayList<>(IntStream.range(0, chunk.size()).boxed().toList());

        for (int attempt = 0; attempt <= maxRetries && !pending.isEmpty(); attempt++) {
            if (attempt > 0 && !backOff(attempt)) {
                break;
            }
            pending = attemptOnce(chunk, pending, delivery, resolved);
        }
        // 재시도를 다 썼는데 남은 것은 마지막 시도의 실패 결과를 그대로 둔다.
        return List.of(resolved);
    }

    /** 대기 중인 토큰만 한 번 보내고, 다시 시도할 인덱스를 돌려준다. */
    private List<Integer> attemptOnce(List<PushTarget> chunk, List<Integer> pending, PushDelivery delivery,
                                      PushResult[] resolved) {
        List<Message> messages = pending.stream()
                .map(i -> toMessage(chunk.get(i).token(), chunk.get(i).message(), delivery))
                .toList();

        BatchResponse response;
        try {
            response = messaging.sendEach(messages);
        } catch (FirebaseMessagingException e) {
            // 호출 자체가 실패했다. 어느 토큰 탓인지 알 수 없으므로 토큰을 무효로 판정하지 않는다.
            Kind kind = classify(e) == Kind.RETRYABLE ? Kind.RETRYABLE : Kind.FAILED;
            log.warn("FCM 배치 호출 실패: errorCode={}, count={}", describe(e), pending.size());
            List<Integer> retry = new ArrayList<>();
            for (int i : pending) {
                resolved[i] = PushResult.failed(chunk.get(i).token(), describe(e));
                if (kind == Kind.RETRYABLE) {
                    retry.add(i);
                }
            }
            return retry;
        }

        List<SendResponse> responses = response.getResponses();
        List<Integer> retry = new ArrayList<>();
        for (int k = 0; k < pending.size(); k++) {
            int i = pending.get(k);
            String token = chunk.get(i).token();
            SendResponse sendResponse = responses.get(k);
            if (sendResponse.isSuccessful()) {
                resolved[i] = PushResult.sent(token);
                continue;
            }
            FirebaseMessagingException exception = sendResponse.getException();
            String errorCode = describe(exception);
            switch (classify(exception)) {
                case INVALID_TOKEN -> resolved[i] = PushResult.invalidToken(token, errorCode);
                case RETRYABLE -> {
                    resolved[i] = PushResult.failed(token, errorCode);
                    retry.add(i);
                }
                case FAILED -> resolved[i] = PushResult.failed(token, errorCode);
            }
        }
        return retry;
    }

    /**
     * 실패를 세 갈래로 나눈다. 토큰이 죽은 것, 잠시 뒤 다시 하면 되는 것, 그 밖의 것.
     *
     * <p>FCM 이 에러 코드를 주지 않은 경우(HTTP 오류만 온 경우)에는 재시도 가능한 상태만 알아보고,
     * 토큰을 무효로 판정하지는 않는다. 근거 없이 토큰을 지우면 알림을 받을 수 있는 기기를 잃는다.
     */
    private static Kind classify(FirebaseMessagingException e) {
        if (e == null) {
            return Kind.FAILED;
        }
        MessagingErrorCode code = e.getMessagingErrorCode();
        if (code != null) {
            return switch (code) {
                case UNREGISTERED, INVALID_ARGUMENT, SENDER_ID_MISMATCH -> Kind.INVALID_TOKEN;
                case UNAVAILABLE, INTERNAL, QUOTA_EXCEEDED -> Kind.RETRYABLE;
                default -> Kind.FAILED;
            };
        }
        ErrorCode errorCode = e.getErrorCode();
        if (errorCode == ErrorCode.UNAVAILABLE || errorCode == ErrorCode.INTERNAL
                || errorCode == ErrorCode.RESOURCE_EXHAUSTED || errorCode == ErrorCode.DEADLINE_EXCEEDED) {
            return Kind.RETRYABLE;
        }
        return Kind.FAILED;
    }

    private static String describe(FirebaseMessagingException e) {
        if (e == null) {
            return "UNKNOWN";
        }
        if (e.getMessagingErrorCode() != null) {
            return e.getMessagingErrorCode().name();
        }
        return e.getErrorCode() == null ? "UNKNOWN" : e.getErrorCode().name();
    }

    /**
     * 메시지 자체가 잘못됐을 때 모든 토큰을 지우는 사고를 막는다.
     *
     * <p>{@code INVALID_ARGUMENT} 는 토큰이 잘못됐을 때도, 요청 내용이 잘못됐을 때도 온다. 내용이 잘못되면
     * 여러 토큰이 전부 같은 코드로 실패하는데, 이걸 토큰 탓으로 읽으면 받을 수 있는 기기를 통째로 지운다.
     * 둘 이상을 보냈는데 전부 이 코드면 내용 문제로 보고 지우지 않는다.
     *
     * <p>토큰이 하나뿐이면 구별할 수 없어 토큰 탓으로 본다.
     */
    private List<PushResult> guardAgainstPayloadError(List<PushResult> results) {
        if (results.size() < 2) {
            return results;
        }
        boolean allInvalidArgument = results.stream().allMatch(result ->
                result.outcome() == PushResult.Outcome.INVALID_TOKEN
                        && MessagingErrorCode.INVALID_ARGUMENT.name().equals(result.errorCode()));
        if (!allInvalidArgument) {
            return results;
        }
        log.error("모든 토큰이 INVALID_ARGUMENT 로 실패했다. 메시지 내용이 잘못된 것으로 보고 토큰을 지우지 않는다: count={}",
                results.size());
        return results.stream()
                .map(result -> PushResult.failed(result.token(), result.errorCode()))
                .toList();
    }

    /** 재시도 전에 기다린다. 기다리다 중단되면 더 시도하지 않는다. */
    private boolean backOff(int attempt) {
        try {
            sleeper.sleep(BACKOFF_BASE_MILLIS << (attempt - 1));
            return true;
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            return false;
        }
    }

    private Message toMessage(String token, PushMessage message, PushDelivery delivery) {
        return baseMessage(message, delivery).setToken(token).build();
    }

    private Message.Builder baseMessage(PushMessage message, PushDelivery delivery) {
        return Message.builder()
                .setNotification(Notification.builder().setBody(message.body()).build())
                .putAllData(message.data())
                .setAndroidConfig(androidConfig(delivery));
    }

    private AndroidConfig androidConfig(PushDelivery delivery) {
        AndroidConfig.Builder builder = AndroidConfig.builder()
                .setPriority(delivery.priority() == PushDelivery.Priority.HIGH
                        ? AndroidConfig.Priority.HIGH
                        : AndroidConfig.Priority.NORMAL);
        if (delivery.ttl() != null) {
            builder.setTtl(delivery.ttl().toMillis());
        }
        if (delivery.channelId() != null) {
            builder.setNotification(AndroidNotification.builder().setChannelId(delivery.channelId()).build());
        }
        return builder.build();
    }

    private String send(Message message) {
        try {
            return messaging.send(message);
        } catch (Exception e) {
            throw new IllegalStateException("FCM 메시지 발송에 실패했습니다.", e);
        }
    }

    private enum Kind {
        INVALID_TOKEN,
        RETRYABLE,
        FAILED
    }

    /** 재시도 사이의 대기. 테스트가 실제로 기다리지 않도록 뺀다. */
    @FunctionalInterface
    interface Sleeper {
        void sleep(long millis) throws InterruptedException;
    }
}
