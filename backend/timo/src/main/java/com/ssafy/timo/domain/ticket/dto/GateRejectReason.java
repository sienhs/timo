package com.ssafy.timo.domain.ticket.dto;

/**
 * 입장 거절 사유. 게이트 앱이 이 코드를 운영자용 문구로 바꾼다
 * ({@code gate/lib/features/scan/models/verification_result.dart} 의 {@code RejectReason}).
 *
 * <p><b>이름을 바꾸면 게이트 앱이 못 알아듣는다.</b> 앱은 모르는 코드를 {@code unknown} 으로
 * 떨어뜨려 중립 문구를 보여주므로 죽지는 않지만, 운영자는 왜 막혔는지 알 수 없게 된다.
 *
 * <p>사유를 더 잘게 쪼개지 않는다. 형식 오류와 서명 불일치를 나눠 알려주면 위조를 시도하는 쪽에
 * "형식은 맞았다" 는 힌트를 주게 된다.
 */
public enum GateRejectReason {

    /** 수명이 지난 QR. 캡처 이미지도 대부분 여기서 걸린다. */
    EXPIRED,
    /** 이미 입장 처리된 티켓. 같은 QR 재사용도, 새로 받은 QR 로 두 번째 입장도 여기다. */
    ALREADY_USED,
    /** 예매 취소·주최사 회수로 회수된 티켓. */
    REVOKED,
    /** 이 게이트가 맡은 공연의 티켓이 아니다. */
    WRONG_CONCERT,
    /** 온체인 현재 소유자와 다르다. 양도 뒤 이전 소유자가 쓰는 경우. */
    SIGNATURE_MISMATCH,
    /** 형식이 다르거나 서명이 맞지 않는다. 위조이거나 우리 QR 이 아니다. */
    INVALID
}
