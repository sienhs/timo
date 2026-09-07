package com.ssafy.timo.domain.seat.entity;

/**
 * 구역 안에서의 좌석 한 자리. 행 번호와 자리 번호로만 이루어진 값이다.
 *
 * <p>{@link Seat} 와 달리 식별자도 상태도 없다. "어느 자리인지"만 필요한 곳 — 좌석을 만들기 전의
 * 배치 정보 — 에서 쓴다.
 *
 * <p>번호는 둘 다 1 부터 시작한다. 여기서 던지는 예외는 마지막 방어선이다. 요청으로 들어온 값은
 * 그 전에 Bean Validation 이 걸러낸다.
 */
public record SeatPosition(int seatNo, int seatCol) {

    public SeatPosition {
        if (seatNo < 1 || seatCol < 1) {
            throw new IllegalArgumentException(
                    "좌석 번호는 1 이상이어야 합니다. (seatNo=" + seatNo + ", seatCol=" + seatCol + ")");
        }
    }
}
