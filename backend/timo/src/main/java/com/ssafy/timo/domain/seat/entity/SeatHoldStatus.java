package com.ssafy.timo.domain.seat.entity;

/**
 * 좌석 선점 한 건의 상태.
 *
 * <p>선점은 좌석 행을 고치지 않고 {@link SeatHold} 행으로 남는다. 그래서 상태는 좌석이 아니라
 * 선점 건이 갖는다. 끝난 선점도 지우지 않고 종료 사유를 남겨 둔다 — 어느 자리가 왜 풀렸는지가
 * 이력으로 필요하고, 지워 버리면 같은 좌석의 재선점과 구분할 수 없다.
 *
 * <pre>
 * HELD ──(회원 취소)──▶ RELEASED
 *   ├──(만료 정리)────▶ EXPIRED
 *   └──(주문 확정)────▶ CONVERTED
 * </pre>
 *
 * <p>{@link #HELD} 만 유효한 선점이다. 나머지 셋은 모두 "이 자리는 비어 있다" 를 뜻하고,
 * 서로 구분하는 것은 사유뿐이다. 좌석 상태를 유도할 때는 {@link #HELD} 인지만 본다.
 */
public enum SeatHoldStatus {

    /** 선점 중. 유일하게 자리를 실제로 붙들고 있는 상태다. */
    HELD,
    /** 회원이 직접 취소했다. */
    RELEASED,
    /** 만료 시각이 지나 정리됐다. */
    EXPIRED,
    /** 주문 확정으로 넘어갔다. 이 자리는 이제 {@code reservation} 이 붙들고 있다. */
    CONVERTED
}
