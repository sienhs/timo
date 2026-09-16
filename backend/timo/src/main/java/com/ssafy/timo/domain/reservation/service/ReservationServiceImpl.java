package com.ssafy.timo.domain.reservation.service;

import com.ssafy.timo.domain.blockchain.ContractClient;
import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
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
import com.ssafy.timo.domain.reservation.exception.ConcertNotOnSaleException;
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
import com.ssafy.timo.domain.wallet.service.WalletService;
import com.ssafy.timo.global.storage.ImageStorage;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.NoSuchElementException;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
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
@Service
@RequiredArgsConstructor
@Transactional
public class ReservationServiceImpl implements ReservationService {

    private static final int CANCELLATION_CUTOFF_HOURS = 24;

    private final MemberRepository memberRepository;
    private final ConcertRepository concertRepository;
    private final SeatHoldRepository seatHoldRepository;
    private final ReservationRepository reservationRepository;
    private final TicketRepository ticketRepository;
    private final WalletService walletService;
    private final TicketVaultClient ticketVaultClient;
    private final TicketNftClient ticketNftClient;
    private final ImageStorage imageStorage;
    private final ApplicationEventPublisher eventPublisher;
    private final Clock clock;

    @Override
    public ReservationDetailResponseDto create(Long memberId, CreateReservationRequestDto request) {
        Long concertId = request.concertId();
        Long seatId = request.seatId();
        LocalDateTime now = LocalDateTime.now(clock);

        Concert concert = concertRepository.findById(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));
        if (concert.getStatus() != ConcertStatus.ON_SALE) {
            throw new ConcertNotOnSaleException(concertId, concert.getStatus());
        }
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

    @Override
    @Transactional(readOnly = true)
    public PagedModel<ReservationSummaryResponseDto> findAll(Long memberId, ReservationListRequestDto request) {
        return new PagedModel<>(reservationRepository
                .findPageByMemberId(memberId, request.status(), request.toPageable())
                .map(reservation -> ReservationSummaryResponseDto.from(reservation, imageStorage)));
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
     * <p>좌석을 별도로 "풀어" 주지 않는다 - {@code SeatStatus}는 {@code reservation.status}에서
     * 유도되므로, {@link Reservation#cancel}이 곧 좌석 반환이다.
     *
     * <p>승계 대기자 자동 재발급은 아직 없다 - 지금은 회수해서 미판매로 남기는 것까지만 한다.
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

        Concert concert = reservation.getConcert();
        LocalDateTime cutoff = concert.getStartDate() == null ? null : concert.getStartDate().minusHours(CANCELLATION_CUTOFF_HOURS);
        LocalDateTime now = LocalDateTime.now(clock);
        if (cutoff != null && !now.isBefore(cutoff)) {
            throw new ReservationNotCancellableException(reservationId, "공연 시작 " + CANCELLATION_CUTOFF_HOURS + "시간 이내에는 취소할 수 없습니다");
        }

        String buyerAddress = walletService.getAddress(memberId);
        String organizerAddress = walletService.getAddress(concert.getOrganizer().getId());
        ticketNftClient.revoke(ticket.getTokenId());
        ticketVaultClient.refund(
                buyerAddress, organizerAddress, concert.getFacePrice(), ContractClient.keccak256(refundRefId(reservation)));

        ticket.revoke();
        reservation.cancel(now);

        return ReservationDetailResponseDto.from(reservation, ticket, imageStorage);
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
