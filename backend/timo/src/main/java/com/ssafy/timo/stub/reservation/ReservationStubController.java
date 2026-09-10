package com.ssafy.timo.stub.reservation;

import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.reservation.controller.ReservationApi;
import com.ssafy.timo.domain.reservation.dto.CreateReservationRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationDetailResponseDto;
import com.ssafy.timo.domain.reservation.dto.ReservationListRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationSummaryResponseDto;
import com.ssafy.timo.domain.reservation.entity.ReservationStatus;
import com.ssafy.timo.domain.reservation.exception.AlreadyReservedException;
import com.ssafy.timo.domain.reservation.exception.ConcertNotOnSaleException;
import com.ssafy.timo.domain.reservation.exception.ReservationNotCancellableException;
import com.ssafy.timo.domain.reservation.exception.ReservationNotFoundException;
import com.ssafy.timo.domain.seat.entity.SeatStatus;
import com.ssafy.timo.domain.seat.exception.SeatHoldNotOwnedException;
import com.ssafy.timo.domain.seat.exception.SeatNotFoundException;
import com.ssafy.timo.domain.seat.exception.SeatNotHeldException;
import com.ssafy.timo.global.storage.ImageStorage;
import com.ssafy.timo.stub.StubController;
import com.ssafy.timo.stub.StubFixtures;
import com.ssafy.timo.stub.StubFixtures.ConcertFixture;
import com.ssafy.timo.stub.StubFixtures.SeatFixture;
import com.ssafy.timo.stub.StubHashes;
import com.ssafy.timo.stub.concert.ConcertStore;
import com.ssafy.timo.stub.seat.SeatStateStore;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;

import java.net.URI;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;

/**
 * 예매(주문) API 스텁 (v0).
 *
 * <p>좌석 스텁의 선점 상태({@link SeatStateStore}) 위에서 동작한다. 내가 선점 중인 좌석만 주문할 수 있고,
 * 주문이 확정되면 그 좌석은 곧바로 {@code OCCUPIED} 가 된다. 실제 규약과 같다. 좌석 배정과 잔액 차감은
 * 주문 시점에 끝나고 온체인 발행만 뒤따른다.
 *
 * <p>온체인 발행은 시간으로 흉내 낸다. 주문 뒤 {@link StubFixtures#MINT_DELAY_SECONDS} 초가 지나면
 * 조회 결과가 {@code MINTED} 로 바뀐다. 화면이 폴링으로 발행 완료를 그리는 흐름을 볼 수 있다.
 * 예약 좌석 {@link StubFixtures#MINT_FAIL_SEAT_ID} 는 같은 시간 뒤 {@code MINT_FAILED} 가 되고, 다시
 * {@link StubFixtures#REFUND_DELAY_SECONDS} 초 뒤 {@code REFUNDED} 가 되며 좌석이 풀린다.
 * 상태 전이는 조회 시점에 계산하므로, 실패 좌석은 주문을 한 번 조회해야 좌석 목록에서도 풀려 보인다.
 *
 * <p>요청자 개념이 없어 이 프로세스의 주문은 전부 한 사람의 것이다. 1인 1매도 그 기준으로 본다.
 *
 * <p>잔액 차감·환원, 티켓 발행·회수는 지갑·티켓 도메인의 일이라 여기서 재현하지 않는다. 취소는 주문 상태만
 * {@code CANCELLED} 로 바꾸고 좌석은 회수된 채(선택 화면 미노출) 둔다.
 */
@StubController
@RequestMapping(ReservationStubController.BASE_PATH)
public class ReservationStubController implements ReservationApi {

    static final String BASE_PATH = "/api/v0/reservations";

    /** "취소는 공연 시작 24시간 전까지만 성립한다." */
    private static final int CANCEL_DEADLINE_HOURS = 24;

    private final SeatStateStore seatStateStore;
    private final ConcertStore concertStore;
    private final ImageStorage imageStorage;
    private final Clock clock;
    private final AtomicLong idSequence = new AtomicLong(StubFixtures.CREATED_ID_START);
    private final Map<Long, Order> orders = new ConcurrentHashMap<>();

    /** 회원이 취소한 주문과 그 시각. 취소는 시간이 아니라 요청으로 일어나므로 따로 기억한다. */
    private final Map<Long, LocalDateTime> cancelled = new ConcurrentHashMap<>();

    public ReservationStubController(SeatStateStore seatStateStore, ConcertStore concertStore,
                                     ImageStorage imageStorage, Clock clock) {
        this.seatStateStore = seatStateStore;
        this.concertStore = concertStore;
        this.imageStorage = imageStorage;
        this.clock = clock;
    }

    @Override
    public ResponseEntity<ReservationDetailResponseDto> create(CreateReservationRequestDto request) {
        ConcertFixture concert = concertStore.find(request.concertId())
                .orElseThrow(() -> new ConcertNotFoundException(request.concertId()));
        if (concert.status() != ConcertStatus.ON_SALE) {
            throw new ConcertNotOnSaleException(concert.id(), concert.status());
        }

        SeatFixture seat = seatStateStore.find(request.seatId())
                .orElseThrow(() -> new SeatNotFoundException(request.seatId()));
        requireMyHold(seat);

        // 1인 1매. 환불·취소까지 끝난 주문은 보유로 보지 않는다.
        boolean alreadyHolds = orders.values().stream()
                .filter(order -> order.concert().id() == concert.id())
                .map(this::statusOf)
                .anyMatch(status -> status != ReservationStatus.REFUNDED && status != ReservationStatus.CANCELLED);
        if (alreadyHolds) {
            throw new AlreadyReservedException(concert.id());
        }

        // 좌석 배정 + 주문 생성. 실제라면 잔액 차감까지 DB 단일 트랜잭션이다.
        seatStateStore.occupy(seat);
        Order order = new Order(idSequence.getAndIncrement(), concert, seat, LocalDateTime.now(clock));
        orders.put(order.id(), order);

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/" + order.id()))
                .body(toDetail(order));
    }

    @Override
    public ResponseEntity<PagedModel<ReservationSummaryResponseDto>> findAll(ReservationListRequestDto request) {
        List<Order> matched = orders.values().stream()
                .filter(order -> request.status() == null || statusOf(order) == request.status())
                .sorted(Comparator.comparing(Order::createdAt).thenComparingLong(Order::id).reversed())
                .toList();

        Pageable pageable = request.toPageable();
        int from = (int) Math.min(pageable.getOffset(), matched.size());
        int to = Math.min(from + pageable.getPageSize(), matched.size());
        List<ReservationSummaryResponseDto> content = matched.subList(from, to).stream()
                .map(this::toSummary)
                .toList();

        return ResponseEntity.ok(new PagedModel<>(new PageImpl<>(content, pageable, matched.size())));
    }

    @Override
    public ResponseEntity<ReservationDetailResponseDto> find(Long reservationId) {
        return ResponseEntity.ok(toDetail(requireOrder(reservationId)));
    }

    @Override
    public ResponseEntity<ReservationDetailResponseDto> cancel(Long reservationId) {
        Order order = requireOrder(reservationId);
        ReservationStatus status = statusOf(order);
        if (status != ReservationStatus.MINTED) {
            throw new ReservationNotCancellableException(reservationId, "status=" + status);
        }

        LocalDateTime now = LocalDateTime.now(clock);
        LocalDateTime startDate = order.concert().startDate();
        if (startDate != null && !now.plusHours(CANCEL_DEADLINE_HOURS).isBefore(startDate)) {
            throw new ReservationNotCancellableException(reservationId, "공연 시작 24시간 이내");
        }

        // 회수. 좌석은 선택 화면에 다시 나오지 않는다(OCCUPIED 유지). 티켓 회수·환원은 다른 도메인의 일이다.
        cancelled.put(order.id(), now);

        return ResponseEntity.ok(toDetail(order));
    }

    private Order requireOrder(Long reservationId) {
        Order order = orders.get(reservationId);
        if (order == null) {
            throw new ReservationNotFoundException(reservationId);
        }
        return order;
    }

    private void requireMyHold(SeatFixture seat) {
        SeatStatus status = seatStateStore.statusOf(seat);
        if (seatStateStore.isMine(seat) && status == SeatStatus.RESERVED) {
            return;
        }
        if (status == SeatStatus.AVAILABLE) {
            throw new SeatNotHeldException(seat.id());       // 선점 없이 결제. 만료된 선점도 여기.
        }
        throw new SeatHoldNotOwnedException(seat.id());      // 남의 선점·점유, 또는 내가 이미 결제한 자리.
    }

    /**
     * 주문 시각으로부터 흐른 시간으로 발행 상태를 정한다. 실패 좌석은 좌석 회수까지 여기서 처리한다.
     * 조회할 때마다 같은 답이 나오도록 시간만 보고 결정하며, 회수는 멱등이라 여러 번 불려도 같다.
     */
    private ReservationStatus statusOf(Order order) {
        if (cancelled.containsKey(order.id())) {
            return ReservationStatus.CANCELLED;
        }
        long elapsed = Duration.between(order.createdAt(), LocalDateTime.now(clock)).getSeconds();
        if (elapsed < StubFixtures.MINT_DELAY_SECONDS) {
            return ReservationStatus.PENDING_MINT;
        }
        if (order.seat().id() != StubFixtures.MINT_FAIL_SEAT_ID) {
            return ReservationStatus.MINTED;
        }
        if (elapsed < StubFixtures.MINT_DELAY_SECONDS + StubFixtures.REFUND_DELAY_SECONDS) {
            return ReservationStatus.MINT_FAILED;
        }
        seatStateStore.release(order.seat());                 // 보상: 좌석 회수. 잔액 환원은 지갑 도메인 몫.
        return ReservationStatus.REFUNDED;
    }

    private ReservationDetailResponseDto toDetail(Order order) {
        ReservationStatus status = statusOf(order);
        boolean minted = status == ReservationStatus.MINTED || status == ReservationStatus.CANCELLED;
        boolean failed = status == ReservationStatus.MINT_FAILED || status == ReservationStatus.REFUNDED;
        LocalDateTime updatedAt = switch (status) {
            case PENDING_MINT -> order.createdAt();
            case MINTED, MINT_FAILED -> order.createdAt().plusSeconds(StubFixtures.MINT_DELAY_SECONDS);
            case REFUNDED -> order.createdAt()
                    .plusSeconds(StubFixtures.MINT_DELAY_SECONDS + StubFixtures.REFUND_DELAY_SECONDS);
            case CANCELLED -> cancelled.get(order.id());
        };

        return new ReservationDetailResponseDto(
                order.id(),
                orderIdOf(order.id()),
                order.concert().id(),
                order.concert().title(),
                imageStorage.getUrl(order.concert().posterImageKey()),
                order.concert().startDate(),
                order.concert().venueName(),
                order.seat().id(),
                order.seat().section().id(),
                order.seat().section().name(),
                order.seat().seatNo(),
                order.seat().seatCol(),
                order.seat().section().price(),
                status,
                minted ? String.valueOf(order.id()) : null,
                minted ? StubHashes.of("mint:" + order.id()) : null,
                status == ReservationStatus.PENDING_MINT ? 0 : failed ? 3 : 1,
                failed ? StubFixtures.MINT_FAILURE_REASON : null,
                order.createdAt(),
                updatedAt);
    }

    private ReservationSummaryResponseDto toSummary(Order order) {
        return new ReservationSummaryResponseDto(
                order.id(),
                order.concert().id(),
                order.concert().title(),
                imageStorage.getUrl(order.concert().posterImageKey()),
                order.concert().startDate(),
                order.concert().venueName(),
                order.seat().section().name(),
                order.seat().seatNo(),
                order.seat().seatCol(),
                order.seat().section().price(),
                statusOf(order),
                order.createdAt());
    }

    /** 설계 초안 5절의 규칙 {@code keccak256("order:" + reservationId)}. 같은 주문이면 재시도해도 같은 값이다. */
    private static String orderIdOf(long reservationId) {
        return StubHashes.of("order:" + reservationId);
    }

    private record Order(long id, ConcertFixture concert, SeatFixture seat, LocalDateTime createdAt) {
    }
}
