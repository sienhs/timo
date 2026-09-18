package com.ssafy.timo.domain.reservation.service;

import com.ssafy.timo.domain.concert.entity.BookingBlockReason;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.reservation.exception.BookingClosedException;
import com.ssafy.timo.domain.reservation.exception.BookingNotOpenException;
import com.ssafy.timo.domain.reservation.exception.ConcertNotOnSaleException;

import java.time.LocalDateTime;

/**
 * 예매 가능 시간 판정을 예외로 바꾼다.
 *
 * <p>{@link Concert#bookingBlockReason}이 정한 순서(상태 → 오픈 전 → 마감 후)를 그대로 따르며,
 * 선점({@code SeatServiceImpl.hold})과 결제({@code ReservationServiceImpl.create}) 양쪽이 이 한
 * 지점만 호출하게 해 판정 로직이 서비스마다 갈라지지 않게 한다.
 */
public final class BookingWindowGuard {

    private BookingWindowGuard() {
    }

    /**
     * 막을 사유가 있으면 그 사유에 맞는 예외를 던진다. 없으면 아무 일도 하지 않는다.
     *
     * <p>switch 를 <b>문이 아니라 식</b>으로 쓴다. 문으로 두면 자바가 enum 에 대해 빠짐없음을
     * 따지지 않아, {@link BookingBlockReason} 에 사유를 하나 더 넣어도 경고 없이 컴파일된다.
     * 그러면 새 사유가 어느 case 에도 안 걸려 이 메서드가 그냥 반환하고, 엔티티가 막으라고 한
     * 공연을 선점·결제가 조용히 통과시킨다. 식으로 쓰면 그 순간 컴파일이 깨진다 - 막지 못하는
     * 것보다 빌드가 깨지는 편이 낫다. 같은 이유로 {@code default} 는 두지 않는다. 그걸 두면
     * 다시 컴파일이 통과해 버린다.
     */
    public static void check(Concert concert, LocalDateTime now) {
        concert.bookingBlockReason(now).ifPresent(reason -> {
            throw switch (reason) {
                case NOT_ON_SALE -> new ConcertNotOnSaleException(concert.getId(), concert.getStatus());
                case NOT_OPEN -> new BookingNotOpenException(concert.getId(), concert.getOpenAt());
                case CLOSED -> new BookingClosedException(concert.getId(), concert.getStartDate());
            };
        });
    }
}
