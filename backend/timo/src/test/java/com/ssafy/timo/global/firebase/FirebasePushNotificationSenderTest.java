package com.ssafy.timo.global.firebase;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.google.api.client.json.gson.GsonFactory;
import com.google.firebase.ErrorCode;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.SendResponse;
import com.ssafy.timo.global.firebase.PushResult.Outcome;
import java.io.IOException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.IntStream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.mockito.ArgumentCaptor;

/**
 * FCM 호출을 흉내 내서 발송기의 판단을 확인한다. 실제 FCM 에는 닿지 않는다.
 *
 * <p>확인하려는 것은 세 가지다. 어떤 실패가 토큰을 지우게 하는지, 어떤 실패를 다시 시도하는지, 그리고
 * 메시지가 실제로 어떤 모양으로 나가는지. 앞의 둘은 잘못 판단하면 조용히 알림이 끊기거나 멀쩡한 기기가
 * 지워지므로 경계를 하나씩 본다.
 */
class FirebasePushNotificationSenderTest {

    private static final PushDelivery NORMAL =
            new PushDelivery(PushDelivery.Priority.NORMAL, Duration.ofHours(24), "general");

    private final FirebaseMessaging messaging = mock(FirebaseMessaging.class);
    private final List<Long> sleeps = new ArrayList<>();

    private FirebasePushNotificationSender sender(int maxRetries) {
        return new FirebasePushNotificationSender(messaging, maxRetries, sleeps::add);
    }

    @AfterEach
    void clearInterrupt() {
        Thread.interrupted();
    }

    @Test
    @DisplayName("전부 성공하면 요청한 순서 그대로 SENT 로 돌려준다")
    void sendEach_allSuccess_keepsOrder() throws Exception {
        doReturn(batch(ok(), ok(), ok())).when(messaging).sendEach(anyList());

        List<PushResult> results = sender(2).sendEach(targets("a", "b", "c"), NORMAL);

        assertThat(results).extracting(PushResult::token).containsExactly("a", "b", "c");
        assertThat(results).extracting(PushResult::outcome).containsOnly(Outcome.SENT);
        assertThat(sleeps).isEmpty();
    }

    @Test
    @DisplayName("토큰이 죽었다는 코드 셋은 INVALID_TOKEN 이고 다시 시도하지 않는다")
    void sendEach_deadTokenCodes_areInvalidAndNotRetried() throws Exception {
        doReturn(batch(
                ok(),
                fail(MessagingErrorCode.UNREGISTERED),
                fail(MessagingErrorCode.INVALID_ARGUMENT),
                fail(MessagingErrorCode.SENDER_ID_MISMATCH))).when(messaging).sendEach(anyList());

        List<PushResult> results = sender(2).sendEach(targets("good", "gone", "bad", "mismatch"), NORMAL);

        assertThat(results).extracting(PushResult::outcome)
                .containsExactly(Outcome.SENT, Outcome.INVALID_TOKEN, Outcome.INVALID_TOKEN, Outcome.INVALID_TOKEN);
        assertThat(results).extracting(PushResult::errorCode)
                .containsExactly(null, "UNREGISTERED", "INVALID_ARGUMENT", "SENDER_ID_MISMATCH");
        verify(messaging, times(1)).sendEach(anyList());
        assertThat(sleeps).isEmpty();
    }

    @ParameterizedTest
    @EnumSource(value = MessagingErrorCode.class, names = {"UNAVAILABLE", "INTERNAL", "QUOTA_EXCEEDED"})
    @DisplayName("일시적인 오류는 실패한 토큰만 골라 다시 보내고, 성공한 토큰은 다시 보내지 않는다")
    void sendEach_transientError_retriesOnlyFailedTokens(MessagingErrorCode transientCode) throws Exception {
        BatchResponse firstAttempt = batch(ok(), fail(transientCode));
        BatchResponse secondAttempt = batch(ok());
        doReturn(firstAttempt).doReturn(secondAttempt).when(messaging).sendEach(anyList());

        List<PushResult> results = sender(2).sendEach(targets("t1", "t2"), NORMAL);

        assertThat(results).extracting(PushResult::outcome).containsExactly(Outcome.SENT, Outcome.SENT);
        List<List<Message>> calls = sentBatches(2);
        assertThat(calls.get(0)).hasSize(2);
        assertThat(calls.get(1)).hasSize(1);
        assertThat(json(calls.get(1).get(0))).contains("\"token\":\"t2\"");
        assertThat(sleeps).containsExactly(500L);
    }

    @Test
    @DisplayName("재시도를 다 써도 실패하면 FAILED 이고, 대기는 500ms 에서 두 배씩 늘어난다")
    void sendEach_transientErrorForever_failsAfterBackoff() throws Exception {
        doReturn(batch(fail(MessagingErrorCode.UNAVAILABLE))).when(messaging).sendEach(anyList());

        List<PushResult> results = sender(2).sendEach(targets("t1"), NORMAL);

        assertThat(results).singleElement().satisfies(result -> {
            assertThat(result.outcome()).isEqualTo(Outcome.FAILED);
            assertThat(result.errorCode()).isEqualTo("UNAVAILABLE");
        });
        verify(messaging, times(3)).sendEach(anyList());
        assertThat(sleeps).containsExactly(500L, 1000L);
    }

    @Test
    @DisplayName("재시도 횟수가 0 이면 다시 시도하지 않는다")
    void sendEach_zeroRetries_doesNotRetry() throws Exception {
        doReturn(batch(fail(MessagingErrorCode.UNAVAILABLE))).when(messaging).sendEach(anyList());

        List<PushResult> results = sender(0).sendEach(targets("t1"), NORMAL);

        assertThat(results).singleElement().extracting(PushResult::outcome).isEqualTo(Outcome.FAILED);
        verify(messaging, times(1)).sendEach(anyList());
        assertThat(sleeps).isEmpty();
    }

    @Test
    @DisplayName("인증 오류처럼 토큰 탓이 아닌 실패는 FAILED 이고 다시 시도하지도 토큰을 지우지도 않는다")
    void sendEach_nonTokenError_isFailedWithoutRetry() throws Exception {
        doReturn(batch(fail(MessagingErrorCode.THIRD_PARTY_AUTH_ERROR))).when(messaging).sendEach(anyList());

        List<PushResult> results = sender(2).sendEach(targets("t1"), NORMAL);

        assertThat(results).singleElement().extracting(PushResult::outcome).isEqualTo(Outcome.FAILED);
        verify(messaging, times(1)).sendEach(anyList());
        assertThat(sleeps).isEmpty();
    }

    @Test
    @DisplayName("FCM 코드가 없이 HTTP 수준 오류만 오면 재시도할 수 있는 상태만 다시 시도한다")
    void sendEach_noMessagingCode_fallsBackToErrorCode() throws Exception {
        BatchResponse firstAttempt = batch(failWithoutCode(ErrorCode.UNAVAILABLE));
        BatchResponse secondAttempt = batch(ok());
        doReturn(firstAttempt).doReturn(secondAttempt).when(messaging).sendEach(anyList());

        List<PushResult> retried = sender(2).sendEach(targets("t1"), NORMAL);
        assertThat(retried).singleElement().extracting(PushResult::outcome).isEqualTo(Outcome.SENT);

        doReturn(batch(failWithoutCode(ErrorCode.NOT_FOUND))).when(messaging).sendEach(anyList());
        List<PushResult> notFound = sender(2).sendEach(targets("t2"), NORMAL);
        assertThat(notFound).singleElement().extracting(PushResult::outcome)
                .as("근거 없이 토큰을 지우지 않는다").isEqualTo(Outcome.FAILED);
    }

    @Test
    @DisplayName("토큰이 500개를 넘으면 500개씩 나눠 보내고 결과는 요청 순서를 지킨다")
    void sendEach_moreThanLimit_isChunkedByFiveHundred() throws Exception {
        when(messaging.sendEach(anyList())).thenAnswer(invocation -> {
            List<?> messages = invocation.getArgument(0);
            return batch(IntStream.range(0, messages.size()).mapToObj(i -> ok()).toArray(SendResponse[]::new));
        });
        String[] tokens = IntStream.range(0, 1200).mapToObj(i -> "t" + i).toArray(String[]::new);

        List<PushResult> results = sender(2).sendEach(targets(tokens), NORMAL);

        assertThat(results).hasSize(1200);
        assertThat(results).extracting(PushResult::token).containsExactly(tokens);
        assertThat(sentBatches(3)).extracting(List::size).containsExactly(500, 500, 200);
    }

    @Test
    @DisplayName("호출 자체가 일시적으로 실패하면 묶음 전체를 다시 보낸다")
    void sendEach_callLevelTransientFailure_isRetried() throws Exception {
        FirebaseMessagingException unavailable = exception(MessagingErrorCode.UNAVAILABLE);
        BatchResponse success = batch(ok(), ok());
        doThrow(unavailable).doReturn(success).when(messaging).sendEach(anyList());

        List<PushResult> results = sender(2).sendEach(targets("a", "b"), NORMAL);

        assertThat(results).extracting(PushResult::outcome).containsOnly(Outcome.SENT);
        assertThat(sleeps).containsExactly(500L);
    }

    @Test
    @DisplayName("호출 자체가 실패했을 때는 어느 토큰 탓인지 모르므로 INVALID_TOKEN 으로 판정하지 않는다")
    void sendEach_callLevelInvalidArgument_isFailedNotInvalidToken() throws Exception {
        doThrow(exception(MessagingErrorCode.INVALID_ARGUMENT)).when(messaging).sendEach(anyList());

        List<PushResult> results = sender(2).sendEach(targets("a", "b"), NORMAL);

        assertThat(results).extracting(PushResult::outcome).containsOnly(Outcome.FAILED);
        verify(messaging, times(1)).sendEach(anyList());
    }

    @Test
    @DisplayName("둘 이상을 보냈는데 전부 INVALID_ARGUMENT 이면 메시지 내용 문제로 보고 토큰을 지우지 않는다")
    void sendEach_allInvalidArgument_isTreatedAsPayloadProblem() throws Exception {
        doReturn(batch(fail(MessagingErrorCode.INVALID_ARGUMENT), fail(MessagingErrorCode.INVALID_ARGUMENT)))
                .when(messaging).sendEach(anyList());

        List<PushResult> results = sender(2).sendEach(targets("a", "b"), NORMAL);

        assertThat(results).extracting(PushResult::outcome).containsOnly(Outcome.FAILED);
        assertThat(results).extracting(PushResult::errorCode).containsOnly("INVALID_ARGUMENT");
    }

    @Test
    @DisplayName("토큰이 하나뿐이면 INVALID_ARGUMENT 를 토큰 탓으로 본다")
    void sendEach_singleInvalidArgument_isInvalidToken() throws Exception {
        doReturn(batch(fail(MessagingErrorCode.INVALID_ARGUMENT))).when(messaging).sendEach(anyList());

        List<PushResult> results = sender(2).sendEach(targets("a"), NORMAL);

        assertThat(results).singleElement().extracting(PushResult::outcome).isEqualTo(Outcome.INVALID_TOKEN);
    }

    @Test
    @DisplayName("대기 중에 중단되면 더 시도하지 않고 중단 상태를 되돌려 놓는다")
    void sendEach_interruptedWhileBackingOff_stopsRetrying() throws Exception {
        doReturn(batch(fail(MessagingErrorCode.UNAVAILABLE))).when(messaging).sendEach(anyList());
        FirebasePushNotificationSender interrupted = new FirebasePushNotificationSender(messaging, 2, millis -> {
            throw new InterruptedException();
        });

        List<PushResult> results = interrupted.sendEach(targets("t1"), NORMAL);

        assertThat(results).singleElement().extracting(PushResult::outcome).isEqualTo(Outcome.FAILED);
        verify(messaging, times(1)).sendEach(anyList());
        assertThat(Thread.currentThread().isInterrupted()).isTrue();
    }

    @Test
    @DisplayName("메시지에는 제목이 없고 본문과 data, 채널, 우선순위, 유효 시간이 실린다")
    void sendEach_payload_hasBodyDataChannelPriorityAndTtl() throws Exception {
        doReturn(batch(ok())).when(messaging).sendEach(anyList());
        PushDelivery entry = new PushDelivery(PushDelivery.Priority.HIGH, Duration.ofHours(2), "entry");
        PushMessage message = new PushMessage("입장할 수 있어요", Map.of("notificationId", "7", "unreadCount", "3"));

        sender(2).sendEach(List.of(new PushTarget("t1", message)), entry);

        String json = json(sentBatches(1).get(0).get(0));
        assertThat(json).contains("\"token\":\"t1\"");
        assertThat(json).contains("\"body\":\"입장할 수 있어요\"");
        assertThat(json).doesNotContain("\"title\"");
        assertThat(json).contains("\"notificationId\":\"7\"").contains("\"unreadCount\":\"3\"");
        assertThat(json).contains("\"priority\":\"high\"");
        assertThat(json).contains("\"ttl\":\"7200s\"");
        assertThat(json).contains("\"channel_id\":\"entry\"");
    }

    @Test
    @DisplayName("채널과 유효 시간을 주지 않으면 싣지 않아 앱의 기본 채널로 떨어진다")
    void sendEach_payload_omitsChannelAndTtlWhenUnset() throws Exception {
        doReturn(batch(ok())).when(messaging).sendEach(anyList());
        PushDelivery bare = new PushDelivery(PushDelivery.Priority.NORMAL, null, "  ");

        sender(2).sendEach(List.of(new PushTarget("t1", new PushMessage("본문", Map.of()))), bare);

        String json = json(sentBatches(1).get(0).get(0));
        assertThat(json).contains("\"priority\":\"normal\"");
        assertThat(json).doesNotContain("channel_id").doesNotContain("ttl");
    }

    @Test
    @DisplayName("조용한 푸시는 notification 을 싣지 않아 배너가 뜨지 않고, 채널이 있어도 싣지 않는다")
    void sendEach_silent_hasOnlyDataAndPriority() throws Exception {
        doReturn(batch(ok())).when(messaging).sendEach(anyList());
        PushDelivery delivery = new PushDelivery(PushDelivery.Priority.HIGH, Duration.ofMinutes(5), "entry");
        PushMessage message = PushMessage.silent(Map.of("type", "TICKET_ENTERED", "ticketId", "123"));

        sender(2).sendEach(List.of(new PushTarget("t1", message)), delivery);

        String json = json(sentBatches(1).get(0).get(0));
        assertThat(json).contains("\"type\":\"TICKET_ENTERED\"").contains("\"ticketId\":\"123\"");
        assertThat(json).contains("\"priority\":\"high\"");
        assertThat(json).doesNotContain("\"notification\"").doesNotContain("\"body\"")
                .doesNotContain("channel_id");
    }

    // ---------------------------------------------------------------- 헬퍼

    private List<List<Message>> sentBatches(int expectedCalls) throws FirebaseMessagingException {
        @SuppressWarnings("unchecked")
        ArgumentCaptor<List<Message>> captor = ArgumentCaptor.forClass(List.class);
        verify(messaging, times(expectedCalls)).sendEach(captor.capture());
        return captor.getAllValues();
    }

    private static String json(Message message) throws IOException {
        return GsonFactory.getDefaultInstance().toString(message);
    }

    private static List<PushTarget> targets(String... tokens) {
        List<PushTarget> targets = new ArrayList<>();
        for (String token : tokens) {
            targets.add(new PushTarget(token, new PushMessage("본문", Map.of())));
        }
        return targets;
    }

    private static BatchResponse batch(SendResponse... responses) {
        BatchResponse batch = mock(BatchResponse.class);
        when(batch.getResponses()).thenReturn(List.of(responses));
        return batch;
    }

    private static SendResponse ok() {
        SendResponse response = mock(SendResponse.class);
        when(response.isSuccessful()).thenReturn(true);
        return response;
    }

    private static SendResponse fail(MessagingErrorCode code) {
        SendResponse response = mock(SendResponse.class);
        FirebaseMessagingException exception = exception(code);
        when(response.isSuccessful()).thenReturn(false);
        when(response.getException()).thenReturn(exception);
        return response;
    }

    private static SendResponse failWithoutCode(ErrorCode errorCode) {
        FirebaseMessagingException exception = mock(FirebaseMessagingException.class);
        when(exception.getMessagingErrorCode()).thenReturn(null);
        when(exception.getErrorCode()).thenReturn(errorCode);
        SendResponse response = mock(SendResponse.class);
        when(response.isSuccessful()).thenReturn(false);
        when(response.getException()).thenReturn(exception);
        return response;
    }

    private static FirebaseMessagingException exception(MessagingErrorCode code) {
        FirebaseMessagingException exception = mock(FirebaseMessagingException.class);
        when(exception.getMessagingErrorCode()).thenReturn(code);
        return exception;
    }
}
