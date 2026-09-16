package com.ssafy.timo.domain.transfer.service;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.dto.CreateListingRequestDto;
import com.ssafy.timo.domain.transfer.dto.ListingDetailResponseDto;
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.exception.ListPriceExceedsFacePriceException;
import com.ssafy.timo.domain.transfer.exception.ListingAlreadyClosedException;
import com.ssafy.timo.domain.transfer.exception.ListingNotFoundException;
import com.ssafy.timo.domain.transfer.exception.NotListingSellerException;
import com.ssafy.timo.domain.transfer.exception.NotTicketOwnerException;
import com.ssafy.timo.domain.transfer.exception.TicketNotFoundException;
import com.ssafy.timo.domain.transfer.exception.TicketNotListableException;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigInteger;
import java.time.Clock;
import java.time.LocalDateTime;

/**
 * 양도 매물 등록.
 *
 * <p><b>요청자를 본문으로 받지 않는다.</b> 컨트롤러가 {@code @CurrentMember} 로 access token 의
 * {@code sub} 에서 꺼내 넘겨 준다. 본문으로 받으면 남의 티켓 식별자와 남의 회원 식별자를 함께 넣는
 * 통로가 생긴다.
 *
 * <h2>소유자를 어떻게 판정하는가</h2>
 *
 * <p>{@link Ticket} 에는 소유자 칼럼이 없다. 소유권의 정본은 온체인 {@code TicketNFT} 이고, DB 가
 * 아는 것은 {@code ticket.reservation.member} — <b>처음 예매한 사람</b>뿐이다. 양도로 주인이 바뀌어도
 * 그 값은 변하지 않는다.
 *
 * <p>그래서 예매자만 보고 판정하면 <b>판 사람이 같은 티켓을 다시 등록할 수 있다.</b> 매물 유니크
 * 제약도 이것을 막지 못한다 — 먼저 판 매물은 이미 {@code SOLD} 로 닫혀 있어 "열려 있는 매물 하나"
 * 규칙에 걸리지 않는다. 현재 소유자는 {@link #currentOwnerId} 가 체결 이력에서 유도한다.
 *
 * <p>온체인 연동이 붙으면 실제로 자산이 움직이기 직전에 {@code ownerOf(tokenId)} 대조가 함께
 * 들어가야 한다. 이 판정은 DB 미러이지 정본이 아니다.
 *
 * <h2>티켓 상태는 바꾸지 않는다</h2>
 *
 * <p>등록해도 {@code ticket.status} 는 {@link TicketStatus#OWNED} 에 머문다. {@code Ticket} 에
 * {@code LISTED} 로 가는 전이 메서드가 없고, 티켓 도메인은 이쪽 소관이 아니라 임의로 만들지 않는다.
 * 매물의 생명주기는 {@code ticket_listing.status} 가 정본이므로 등록·취소·체결 판정에는 지장이 없다.
 *
 * <p>대신 <b>온체인 연동 전까지 구멍이 하나 남는다</b> — 등록 중인 티켓의 예매를 취소할 수 있다.
 * 예매 취소는 티켓이 {@code OWNED} 일 때만 성립하는데({@code ReservationServiceImpl.cancel}) 등록해도
 * {@code OWNED} 그대로이기 때문이다. 온체인 {@code listForTransfer} 가 붙으면 컨트랙트의
 * {@code revoke} 가 {@code LISTED} 티켓을 거부하므로 저절로 닫힌다.
 */
@Service
@RequiredArgsConstructor
public class ListingService {

    private final TicketRepository ticketRepository;
    private final TicketListingRepository ticketListingRepository;
    private final TicketTradeRepository ticketTradeRepository;
    private final ImageStorage imageStorage;
    private final Clock clock;

    /**
     * 내 티켓을 양도 매물로 연다.
     *
     * <p>검사 순서는 먼저 걸리는 것 하나만 응답한다.
     *
     * <ol>
     *   <li>티켓이 있는가 → 404</li>
     *   <li>내가 현재 소유자인가 → 403</li>
     *   <li>티켓이 발행 완료 상태인가 → 409</li>
     *   <li>진행 중인 등록이 없는가 → 409</li>
     *   <li>등록가가 정가 이하인가 → 400</li>
     * </ol>
     *
     * <p>4번을 5번보다 먼저 보는 이유는, 이미 등록된 티켓에 대해 "가격이 잘못됐다"고 답하면
     * 사용자가 가격을 고쳐 다시 시도하게 되기 때문이다. 고쳐도 결과는 같다.
     */
    @Transactional
    public ListingDetailResponseDto register(CreateListingRequestDto request, Long memberId) {
        Long ticketId = request.ticketId();

        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new TicketNotFoundException(ticketId));

        if (!currentOwnerId(ticket).equals(memberId)) {
            // 남의 티켓이다. 존재 자체는 이미 위에서 드러났지만, 그 이상(어느 공연·어느 좌석인지)은
            // 알려주지 않는다.
            throw new NotTicketOwnerException(ticketId);
        }
        if (ticket.getStatus() != TicketStatus.OWNED) {
            // 발행 전(PENDING_MINT · MINT_FAILED · REFUNDED)이거나 입장·회수된 티켓이다.
            // 발행 전 티켓은 tokenId 가 없어 온체인에 올릴 대상 자체가 없다.
            throw new TicketNotListableException(ticketId, "티켓 상태가 " + ticket.getStatus() + " 다");
        }
        if (ticketListingRepository.existsByTicketIdAndStatus(ticketId, ListingStatus.LISTED)) {
            // 흔한 경우를 친절한 메시지로 걸러낼 뿐이다. 최종 방어선은 uk_listing_ticket_active 다.
            throw new TicketNotListableException(ticketId, "이미 등록 중이다");
        }

        Reservation reservation = ticket.getReservation();
        Concert concert = reservation.getConcert();
        long faceValue = faceValueOf(concert);
        long price = request.price();
        if (price > faceValue) {
            throw new ListPriceExceedsFacePriceException(price, faceValue);
        }

        TicketListing listing = TicketListing.open(
                ticketId,
                memberId,
                concert,
                reservation.getSeat().getSection(),
                price,
                faceValue,
                LocalDateTime.now(clock));

        return ListingDetailResponseDto.from(save(listing, ticketId), imageStorage, memberId);
    }

    /**
     * 등록을 취소한다.
     *
     * <p>행을 지우지 않고 {@link ListingStatus#CANCELED} 로 닫는다. 취소 이력이 남아야 재양도 추적과
     * CS 가 가능하다. 같은 티켓을 다시 팔면 매물이 새로 생긴다.
     *
     * <p>검사는 404(없는 매물) → 403(남의 매물) → 409(이미 종료) 순이다. <b>마지막 판정은 조회가
     * 아니라 전이의 결과로 한다</b> — 상태를 읽어 확인한 뒤 UPDATE 하면, 취소하려는 찰나에 팔린
     * 경우 둘 다 통과한다. 영향 행이 0 이면 남이 먼저 샀거나 이미 취소된 것이다.
     *
     * <p><b>취소 페널티는 없다.</b> 차감 규칙(D-7 100% / 하루 전 80% / 당일 10%)이 기획 미확정이라
     * 넣지 않았다. 정해지면 이 메서드가 잔액을 건드리게 되고 응답이 204 가 아니게 된다.
     *
     * <p>온체인 {@code delist} 도 부르지 않는다. 판매자 지갑 서명이 필요한데 커스터디얼이라
     * step-up 인증이 선행돼야 한다.
     */
    @Transactional
    public void cancel(Long listingId, Long memberId) {
        TicketListing listing = ticketListingRepository.findById(listingId)
                .orElseThrow(() -> new ListingNotFoundException(listingId));
        if (!listing.isSeller(memberId)) {
            throw new NotListingSellerException(listingId);
        }

        int closed = ticketListingRepository.markCanceledIfListed(listingId, LocalDateTime.now(clock));
        if (closed == 0) {
            throw new ListingAlreadyClosedException(listingId);
        }
    }

    /**
     * 지금 이 티켓의 주인.
     *
     * <p>최근 체결이 있으면 그 구매자, 없으면 처음 예매한 사람이다. 한 티켓이 여러 번 양도될 수
     * 있으므로 가장 마지막 체결을 본다.
     *
     * <p>체결이 {@code PENDING}(온체인 전송 대기)이어도 소유자로 인정한다. 온체인 연동 전까지는
     * 모든 체결이 그 상태에 머물기 때문에, {@code CONFIRMED} 만 인정하면 <b>산 사람이 자기 티켓을
     * 영영 다시 팔 수 없다.</b> 연동 시 이 판정을 다시 볼 것.
     */
    private Long currentOwnerId(Ticket ticket) {
        return ticketTradeRepository.findFirstByTicketIdOrderByTradedAtDescIdDesc(ticket.getId())
                .map(TicketTrade::getBuyerMemberId)
                .orElseGet(() -> ticket.getReservation().getMember().getId());
    }

    /**
     * 정가 이하 판정의 기준값.
     *
     * <p>구역 가격이 아니라 공연 정가다. 예매 결제·환불이 모두 {@code Concert.facePrice} 로
     * 이루어지므로 기준도 그 값이어야 한다.
     *
     * <p>정가가 비어 있으면 <b>기동을 멈추듯 즉시 예외</b>로 끊는다. 0 으로 넘기면 모든 등록이
     * "정가 초과" 로 막히고, 검사를 건너뛰면 정가 초과 판매가 그대로 통과한다 — 이 서비스의
     * 존재 이유가 그 검사다. 온체인 판매 준비({@code Concert.prepareForSale})가 끝나지 않은
     * 공연이라는 뜻이라 사용자가 고칠 수 있는 문제도 아니다.
     */
    private long faceValueOf(Concert concert) {
        BigInteger facePrice = concert.getFacePrice();
        if (facePrice == null) {
            throw new IllegalStateException(
                    "정가가 없는 공연의 티켓은 양도 등록할 수 없습니다 (concertId=" + concert.getId() + ")");
        }
        return facePrice.longValueExact();
    }

    /**
     * 매물을 저장한다.
     *
     * <p>{@code saveAndFlush} 인 이유는 유니크 제약 위반을 <b>이 트랜잭션 안에서</b> 받기 위해서다.
     * {@code save} 만 하면 INSERT 가 커밋 시점까지 미뤄져, 제약 위반이 서비스 밖에서 터진다.
     * 그러면 앱은 409 대신 500 을 받는다.
     *
     * <p>여기 걸리는 것은 선검사를 통과한 뒤 다른 요청이 먼저 등록한 경우다 — 확인과 저장 사이의
     * 틈은 DB 제약만이 막는다.
     */
    private TicketListing save(TicketListing listing, Long ticketId) {
        try {
            return ticketListingRepository.saveAndFlush(listing);
        } catch (DataIntegrityViolationException e) {
            throw new TicketNotListableException(ticketId, "이미 등록 중이다");
        }
    }
}
