package com.ssafy.timo.global.firebase;

/**
 * 토큰 하나에 보낸 결과.
 *
 * @param errorCode 실패했을 때 FCM 이 준 에러 코드 이름. 성공이면 null. 로그에서 "알림함에는 있는데
 *                  푸시만 실패" 를 가려내는 단서다
 */
public record PushResult(String token, Outcome outcome, String errorCode) {

    public enum Outcome {

        /** FCM 이 받아들였다. 기기에 닿았다는 뜻은 아니다. */
        SENT,

        /** 더는 쓸 수 없는 토큰. 앱을 지웠거나 토큰이 바뀌었다. 저장된 토큰을 지워야 한다. */
        INVALID_TOKEN,

        /** 실패했지만 토큰 탓이 아니거나 알 수 없다. 토큰은 지우지 않는다. */
        FAILED
    }

    public static PushResult sent(String token) {
        return new PushResult(token, Outcome.SENT, null);
    }

    public static PushResult invalidToken(String token, String errorCode) {
        return new PushResult(token, Outcome.INVALID_TOKEN, errorCode);
    }

    public static PushResult failed(String token, String errorCode) {
        return new PushResult(token, Outcome.FAILED, errorCode);
    }
}
