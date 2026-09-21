package com.ssafy.timo.domain.reservation.service;

import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.blockchain.ContractClient;
import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.dto.CreateReservationRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationDetailResponseDto;
import com.ssafy.timo.domain.reservation.dto.ReservationListRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationSummaryResponseDto;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.exception.AlreadyReservedException;
import com.ssafy.timo.domain.reservation.exception.ReservationCancelFailedException;
import com.ssafy.timo.domain.reservation.exception.ReservationNotCancellableException;
import com.ssafy.timo.domain.reservation.exception.ReservationNotFoundException;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatHold;
import com.ssafy.timo.domain.seat.exception.SeatHoldNotOwnedException;
import com.ssafy.timo.domain.seat.exception.SeatNotHeldException;
import com.ssafy.timo.domain.seat.repository.SeatHoldRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.domain.wallet.service.WalletService;
import com.ssafy.timo.global.storage.ImageStorage;
import java.math.BigInteger;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.NoSuchElementException;
import java.util.Optional;
import java.util.random.RandomGenerator;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.domain.Page;
import org.springframework.data.web.PagedModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 예매 확정·조회·취소.
 *
 * <p>좌석 판매 그 자체(누가 어느 좌석을 샀는가, {@link Reservation})는 좌석 도메인이 이미 갖춘
 * {@link SeatHold}(선점) 기반 동시성 방어 위에서 이 서비스가 단순히 "선점을 주문으로 전환"하는
 * 것으로 끝난다. 이 서비스가 새로 책임지는 것은 <b>온체인 발행</b>이다 - {@link #create}가 끝나면
 * (커밋되면) 주문은 확정됐고 티켓은 {@link TicketStatus#PENDING_MINT}이지만, 실제 체인 트랜잭션은
 * 아직 나가지 않았다. {@link ReservationSettlementService}가 커밋 이후 비동기로 이어받는다.
 *
 * <p>{@link #cancel}은 반대로 동기다 - 취소는 예매만큼 트래픽이 몰릴 일이 없고, 사용자가 "취소됐다"는
 * 응답을 받는 시점에 실제로 체인 반영(회수·환불)까지 끝나 있는 편이 낫다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional
public class ReservationServiceImpl implements ReservationService {

    private static final int CANCELLATION_CUTOFF_HOURS = 24;

    /**
     * 취소된 자리를 다시 열기까지의 지연. 3분에 1~720초를 더해 3분 1초에서 15분 사이에 풀린다.
     *
     * <p>고정값이 아닌 이유는 풀리는 순간을 겨냥해 대기하는 것을 막기 위해서다. 그래서 이 값은
     * 어떤 응답에도 싣지 않는다 - 내려 주는 순간 랜덤으로 둔 의미가 없어진다.
     */
    private static final Duration RELEASE_BASE_DELAY = Duration.ofMinutes(3);
    private static final int RELEASE_JITTER_SECONDS = 720;

    private final MemberRepository memberRepository;
    private final ConcertRepository concertRepository;
    private final SeatHoldRepository seatHoldRepository;
    private final ReservationRepository reservationRepository;
    private final TicketRepository ticketRepository;
    private final TicketTradeRepository ticketTradeRepository;
    private final TicketListingRepository ticketListingRepository;
    private final WalletService walletService;
    private final TicketVaultClient ticketVaultClient;
    private final TicketNftClient ticketNftClient;
    private final ImageStorage imageStorage;
    private final ApplicationEventPublisher eventPublisher;
    private final RandomGenerator random;
    private final Clock clock;

    @Override
    public ReservationDetailResponseDto create(Long memberId, CreateReservationRequestDto request) {
        Long concertId = request.concertId();
        Long seatId = request.seatId();
        LocalDateTime now = LocalDateTime.now(clock);

        Concert concert = concertRepository.findById(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));
        BookingWindowGuard.check(concert, now);
        if (!concert.isReadyForBooking()) {
            // ON_SALE 은 온체인 등록이 끝난 뒤에만 켜져야 한다 - 여기 걸리면 그 불변식이 깨진 것이다.
            throw new IllegalStateException("ON_SALE 인데 온체인 등록이 안 된 공연입니다 (concertId=" + concertId + ")");
        }

        if (reservationRepository.findPaidOfMember(concertId, memberId).isPresent()) {
            throw new AlreadyReservedException(concertId);
        }

        // 이 공연에서 내가 이 좌석을 유효하게 선점하고 있어야 한다 - 선점 검증에 성공한 것 자체가
        // 좌석이 이 공연 소속임을 보장한다(SeatServiceImpl.hold 가 이미 확인했다).
        SeatHold hold = seatHoldRepository.findActive(concertId, seatId, now)
                .orElseThrow(() -> new SeatNotHeldException(seatId));
        if (!hold.isOwnedBy(memberId)) {
            throw new SeatHoldNotOwnedException(seatId);
        }

        Seat seat = hold.getSeat();
        hold.convert(now);

        Member member = memberRepository.findById(memberId)
                .orElseThrow(() -> new NoSuchElementException("회원을 찾을 수 없습니다 (memberId=" + memberId + ")"));

        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(member)
                .seat(seat)
                .build());

        Ticket ticket = ticketRepository.save(Ticket.builder()
                .reservation(reservation)
                .build());

        eventPublisher.publishEvent(new ReservationCreatedEvent(reservation.getId()));

        return ReservationDetailResponseDto.from(reservation, ticket, imageStorage);
    }

    /**
     * 내 주문 목록.
     *
     * <p>티켓 식별자는 <b>페이지를 다 읽은 뒤 한 번에</b> 모아 온다. {@link Reservation}은 티켓을
     * 가리키지 않아(연관이 {@code Ticket -> Reservation} 단방향) 목록 쿼리에 조인해 올 수 없고,
     * 주문마다 따로 읽으면 페이지 크기만큼 쿼리가 나간다. 그래서 목록 1회 + 티켓 1회로 끝낸다.
     *
     * <p>{@code Reservation}에 역방향 연관을 걸지 않은 이유는
     * {@link TicketRepository#findTicketIdsByReservationIds} 주석을 본다.
     */
    @Override
    @Transactional(readOnly = true)
    public PagedModel<ReservationSummaryResponseDto> findAll(Long memberId, ReservationListRequestDto request) {
        Page<Reservation> page = reservationRepository
                .findPageByMemberId(memberId, request.status(), request.toPageable());
        Map<Long, Long> ticketIds = ticketIdsOf(page.getContent());

        return new PagedModel<>(page.map(reservation ->
                ReservationSummaryResponseDto.from(reservation, ticketIds.get(reservation.getId()), imageStorage)));
    }

    /**
     * 이 주문들의 티켓 식별자를 {@code 주문 id -> 티켓 id} 로 모은다.
     *
     * <p>티켓이 없는 주문은 지도에 자리가 없어 {@code null} 이 실린다. 정상 경로에서는 생기지 않는다 -
     * {@link #create}가 주문과 티켓을 같은 트랜잭션에서 만들기 때문이다. 다만 그 경로를 거치지 않고
     * 들어온 주문(로컬 시드 데이터 등)이 있을 수 있어, 목록 전체를 실패시키는 대신 그 항목만 비워 둔다 -
     * 목록은 "내가 뭘 예매했는지" 를 보여주는 화면이라 티켓 한 장 때문에 통째로 막히면 안 된다.
     */
    private Map<Long, Long> ticketIdsOf(List<Reservation> reservations) {
        if (reservations.isEmpty()) {
            return Map.of();
        }

        List<Long> reservationIds = reservations.stream().map(Reservation::getId).toList();

        return ticketRepository.findTicketIdsByReservationIds(reservationIds).stream()
                .collect(Collectors.toMap(
                        TicketRepository.ReservationTicketId::getReservationId,
                        TicketRepository.ReservationTicketId::getTicketId));
    }

    @Override
    @Transactional(readOnly = true)
    public ReservationDetailResponseDto find(Long memberId, Long reservationId) {
        Reservation reservation = findOwnedOrThrow(reservationId, memberId);
        Ticket ticket = ticketOf(reservationId);

        return ReservationDetailResponseDto.from(reservation, ticket, imageStorage);
    }

    /**
     * 예매를 취소한다. 발행이 끝난 티켓이 정상 소유({@link TicketStatus#OWNED}) 상태일 때만, 공연
     * 시작 24시간 전까지만 성립한다.
     *
     * <p>좌석을 별도로 "풀어" 주지 않는다 - {@code SeatStatus}는 이 주문 행에서 유도되므로
     * {@link Reservation#cancel}이 곧 좌석 반환이다. 다만 즉시가 아니라 해제 시각부터다.
     *
     * <p><b>양도된 티켓은 취소하지 못한다.</b> 체결은 예매 행도 {@code ticket.status} 도 바꾸지 않아
     * 여기 검사만으로는 판 사람이 그대로 통과한다 — 그러면 산 사람의 티켓이 회수되고 환불은 판 사람이
     * 받는다. 등록 중인 티켓도 막는다. 회수된 티켓이 매물로 남으면 그걸 사는 사람이 생긴다.
     * 두 검사는 온체인 호출보다 앞에 둔다.
     *
     * <p>회수한 자리는 <b>즉시 열리지 않는다.</b> 취소 시점에 3분 1초에서 15분 사이의 해제 시각을
     * 뽑아 두고, 그때까지는 누구도 잡을 수 없다. 풀리는 순간을 겨냥해 대기하는 것을 막으려는 것이라
     * 이 시각은 어떤 응답에도 싣지 않는다.
     *
     * <p>취소 자체는 이 트랜잭션에서 끝난다. 사용자는 지연과 무관하게 즉시 취소 완료 응답을 받는다.
     */
    @Override
    public ReservationDetailResponseDto cancel(Long memberId, Long reservationId) {
        Reservation reservation = findOwnedOrThrow(reservationId, memberId);

        if (!reservation.isPaid()) {
            throw new ReservationNotCancellableException(reservationId, "이미 취소됐거나 유효하지 않은 주문입니다");
        }

        Ticket ticket = ticketOf(reservationId);
        if (ticket.getStatus() != TicketStatus.OWNED) {
            throw new ReservationNotCancellableException(reservationId, "발행 전이거나 이미 종료된 티켓입니다");
        }
        if (ticketTradeRepository.existsByTicketId(ticket.getId())) {
            throw new ReservationNotCancellableException(reservationId, "양도된 티켓은 예매 취소할 수 없습니다");
        }
        if (ticketListingRepository.existsByTicketIdAndStatus(ticket.getId(), ListingStatus.LISTED)) {
            throw new ReservationNotCancellableException(reservationId, "양도 등록 중인 티켓입니다. 등록을 먼저 취소해 주세요");
        }

        Concert concert = reservation.getConcert();
        LocalDateTime cutoff = concert.getStartDate() == null ? null : concert.getStartDate().minusHours(CANCELLATION_CUTOFF_HOURS);
        LocalDateTime now = LocalDateTime.now(clock);
        if (cutoff != null && !now.isBefore(cutoff)) {
            throw new ReservationNotCancellableException(reservationId, "공연 시작 " + CANCELLATION_CUTOFF_HOURS + "시간 이내에는 취소할 수 없습니다");
        }

        String buyerAddress = walletService.getAddress(memberId);
        String organizerAddress = walletService.getAddress(concert.getOrganizer().getId());
        BigInteger price = BigInteger.valueOf(reservation.getSeat().getSection().getPrice());

        try {
            ticketNftClient.revoke(ticket.getTokenId());
        } catch (ContractCallException e) {
            // 아직 아무 것도 안 바뀐 상태다 - 회수 자체가 안 먹었으니 그냥 다시 시도하면 된다.
            log.warn("예매 취소 - 온체인 회수 실패 (reservationId={})", reservationId, e);
            throw new ReservationCancelFailedException(e);
        }
        try {
            ticketVaultClient.refund(buyerAddress, organizerAddress, price, ContractClient.keccak256(refundRefId(reservation)));
        } catch (ContractCallException e) {
            // 회수는 이미 온체인에 반영돼 되돌릴 수 없는데 환불이 실패했다 - 이 트랜잭션은 롤백돼
            // DB는 취소 전 그대로 남지만, 실제로는 티켓이 이미 회수된 채라 수동으로 확인해야 한다.
            log.error("예매 취소 - 회수는 됐는데 환불 실패, 수동 개입 필요 (reservationId={})", reservationId, e);
            throw new ReservationCancelFailedException(e);
        }

        ticket.revoke();
        reservation.cancel(now, now.plus(RELEASE_BASE_DELAY).plusSeconds(releaseJitterSeconds()));

        // 응답은 취소 전과 같다. 해제 시각은 여기서 정해지지만 밖으로 내보내지 않는다.
        return ReservationDetailResponseDto.from(reservation, ticket, imageStorage);
    }

    /** 1 이상 720 이하. 0 을 빼는 이유는 지연 하한을 3분 1초로 두기 위해서다. */
    private int releaseJitterSeconds() {
        return random.nextInt(RELEASE_JITTER_SECONDS) + 1;
    }

    static String refundRefId(Reservation reservation) {
        return "reservation-" + reservation.getId() + ":cancel";
    }

    /** 남의 주문은 존재를 알리지 않고 404 다. */
    private Reservation findOwnedOrThrow(Long reservationId, Long memberId) {
        Reservation reservation = reservationRepository.findById(reservationId)
                .orElseThrow(() -> new ReservationNotFoundException(reservationId));
        if (!reservation.isOwnedBy(memberId)) {
            throw new ReservationNotFoundException(reservationId);
        }
        return reservation;
    }

    private Ticket ticketOf(Long reservationId) {
        Optional<Ticket> ticket = ticketRepository.findByReservationId(reservationId);
        return ticket.orElseThrow(() -> new IllegalStateException("주문에 연결된 티켓이 없습니다 (reservationId=" + reservationId + ")"));
    }
}
