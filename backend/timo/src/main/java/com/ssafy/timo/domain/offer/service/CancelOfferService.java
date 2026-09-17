package com.ssafy.timo.domain.offer.service;

import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.offer.dto.CancelOfferListResponseDto;
import com.ssafy.timo.domain.offer.entity.CancelOffer;
import com.ssafy.timo.domain.offer.repository.CancelOfferRepository;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.random.RandomGenerator;

/**
 * 취소표 구매 기회. 예매가 취소되면 그 공연을 찜한 회원 중 한 명을 뽑아 좌석을 1시간 동안 열어 준다.
 *
 * <p>재추첨은 없다. 당첨자가 사지 않으면 기한이 지나는 순간 좌석은 누구나 예매할 수 있는 상태로
 * 돌아간다 — 다음 사람에게 넘기지 않는다. 뽑을 사람이 없으면 기회를 만들지 않고 좌석은 즉시 열린다.
 *
 * <p>기한 판정은 전부 {@code expires_at > now} 다. 스케줄러가 없으므로 "지났다" 는 상태 전이가 아니라
 * 조회 조건이고, 상태를 {@code EXPIRED} 로 적는 것은 같은 좌석에 다음 기회를 열 때뿐이다.
 */
@Service
@RequiredArgsConstructor
public class CancelOfferService {

    /** 구매 기한. 기획 확정값(2026-09-17). */
    static final Duration OFFER_WINDOW = Duration.ofHours(1);

    private final CancelOfferRepository cancelOfferRepository;
    private final ConcertWishRepository concertWishRepository;
    private final TicketRepository ticketRepository;
    private final ConcertRepository concertRepository;
    private final SeatRepository seatRepository;
    private final MemberRepository memberRepository;
    private final ApplicationEventPublisher eventPublisher;
    private final ImageStorage imageStorage;
    private final RandomGenerator random;
    private final Clock clock;

    /**
     * 회수된 좌석에 대해 추첨한다. 예매 취소 트랜잭션 안에서 불린다.
     *
     * <p>제외 대상은 셋이다 — 취소한 본인, 이 공연의 티켓을 지금 들고 있는 사람(1인 1매), 이 공연에서
     * 이미 열린 기회를 가진 사람. 남은 후보가 없으면 빈 값을 돌려주고 아무것도 만들지 않는다.
     *
     * <p>같은 좌석의 지난 기회를 먼저 {@code EXPIRED} 로 닫는다. 유니크 제약이 그 행을 붙들고 있어
     * 닫지 않으면 INSERT 가 실패한다.
     */
    @Transactional
    public Optional<CancelOffer> offerRevokedSeat(Long concertId, Long seatId, Long sourceReservationId,
                                                  Long cancelledMemberId) {
        LocalDateTime now = LocalDateTime.now(clock);
        cancelOfferRepository.expireStaleOfSeat(concertId, seatId, now);

        List<Long> candidates = candidates(concertId, cancelledMemberId, now);
        if (candidates.isEmpty()) {
            return Optional.empty();
        }
        Long winnerId = candidates.get(random.nextInt(candidates.size()));

        CancelOffer offer = cancelOfferRepository.saveAndFlush(CancelOffer.builder()
                .concert(concertRepository.getReferenceById(concertId))
                .seat(seatRepository.getReferenceById(seatId))
                .member(memberRepository.getReferenceById(winnerId))
                .sourceReservationId(sourceReservationId)
                .expiresAt(now.plus(OFFER_WINDOW))
                .build());

        // 알림은 이 이벤트를 받는 쪽이 보낸다. CancelOfferGrantedEvent 주석 참고.
        eventPublisher.publishEvent(new CancelOfferGrantedEvent(
                offer.getId(), winnerId, concertId, seatId, offer.getExpiresAt()));

        return Optional.of(offer);
    }

    /** 내게 열려 있는 기회들. 기한이 가까운 것부터다. */
    @Transactional(readOnly = true)
    public CancelOfferListResponseDto findMine(Long memberId) {
        LocalDateTime now = LocalDateTime.now(clock);
        return CancelOfferListResponseDto.from(cancelOfferRepository.findActiveOfMember(memberId, now), now, imageStorage);
    }

    /**
     * 당첨자의 결제가 이 기회를 쓴 것이면 닫는다. 예매 생성 트랜잭션 안에서 불린다.
     *
     * @return 기회를 써서 산 것이면 true. 기한이 지난 뒤의 결제는 일반 예매라 false 다
     */
    @Transactional
    public boolean acceptIfActive(Long concertId, Long seatId, Long memberId, Long reservationId) {
        return cancelOfferRepository.markAcceptedIfActive(
                concertId, seatId, memberId, reservationId, LocalDateTime.now(clock)) == 1;
    }

    private List<Long> candidates(Long concertId, Long cancelledMemberId, LocalDateTime now) {
        Set<Long> excluded = new HashSet<>(ticketRepository.findHoldingMemberIdsByConcertId(concertId));
        excluded.addAll(cancelOfferRepository.findActiveMemberIdsByConcertId(concertId, now));
        excluded.add(cancelledMemberId);

        List<Long> candidates = new ArrayList<>();
        for (Long memberId : concertWishRepository.findMemberIdsByConcertId(concertId)) {
            if (!excluded.contains(memberId)) {
                candidates.add(memberId);
            }
        }
        return candidates;
    }
}
