package com.ssafy.timo.domain.transfer.service;

import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.wallet.service.WalletService;
import com.ssafy.timo.domain.transfer.dto.CreateListingRequestDto;
import com.ssafy.timo.domain.transfer.dto.ListingDetailResponseDto;
import com.ssafy.timo.domain.transfer.dto.UpdateListingPriceRequestDto;
import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.exception.ListPriceExceedsFacePriceException;
import com.ssafy.timo.domain.transfer.exception.ListingAlreadyClosedException;
import com.ssafy.timo.domain.transfer.exception.ListingNotFoundException;
import com.ssafy.timo.domain.transfer.exception.NotListingSellerException;
import com.ssafy.timo.domain.transfer.exception.NotTicketOwnerException;
import com.ssafy.timo.domain.transfer.exception.TicketNotFoundException;
import com.ssafy.timo.domain.transfer.exception.TicketNotListableException;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.ticket.service.TicketOwnershipService;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
 * <p>DB 소유 관계는 TicketOwnershipService에서 확인한다.
 * 등록·취소의 기존 온체인 ownerOf 검증은 그대로 유지한다.
 *
 * <h2>티켓 상태도 함께 바뀐다</h2>
 *
 * <p>등록·취소 시 온체인 {@code listForTransferFor}/{@code delistFor}를 호출하고
 * {@code ticket.markListed()}/{@code markDelisted()}로 {@code ticket.status}도 맞춘다. 등록 중인
 * 티켓의 예매 취소·입장 QR 발급·게이트 통과가 전부 이 상태로 막힌다 - 안 맞추면 판매자가 판 티켓으로
 * 먼저 입장해버리는 이중 입장이 생긴다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ListingService {

    private final TicketRepository ticketRepository;
    private final TicketListingRepository ticketListingRepository;
    private final TicketOwnershipService ticketOwnershipService;
    private final ImageStorage imageStorage;
    private final MarketHoursService marketHoursService;
    private final TicketNftClient ticketNftClient;
    private final WalletService walletService;
    private final BlockchainProperties blockchainProperties;
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
     *
     * <p><b>운영 시간을 보지 않는다.</b> 닫힌 시간에 올린 매물은 저장만 되고, 남에게는 조회가 열리는
     * 08:00 에 드러난다({@link MarketHoursService}). 등록을 창 안으로 묶으면 정각에 등록 요청이 몰린다.
     */
    @Transactional
    public ListingDetailResponseDto register(CreateListingRequestDto request, Long memberId) {
        Long ticketId = request.ticketId();

        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new TicketNotFoundException(ticketId));

        if (!ticketOwnershipService.isAssignedTo(memberId, ticketId)) {
            // 남의 티켓이다. 존재 자체는 이미 위에서 드러났지만, 그 이상(어느 공연·어느 좌석인지)은 알려주지 않는다.
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
        Seat seat = reservation.getSeat();
        long sectionPrice = sectionPriceOf(seat.getSection());
        long price = request.price();
        if (price > sectionPrice) {
            throw new ListPriceExceedsFacePriceException(price, sectionPrice);
        }

        if (blockchainProperties.hasRealAdminPrivateKey()) {
            String ownerAddress = walletService.getAddress(memberId);
            ticketNftClient.listForTransferFor(ticket.getTokenId(), ownerAddress, BigInteger.valueOf(price));
        } else {
            log.debug("체인 미연결 - listForTransferFor 를 건너뛴다 (ticketId={})", ticketId);
        }
        ticket.markListed();

        TicketListing listing = TicketListing.open(
                ticketId,
                memberId,
                concert,
                seat.getSection(),
                seat.getSeatNo(),
                seat.getSeatCol(),
                price,
                sectionPrice,
                LocalDateTime.now(clock));

        return ListingDetailResponseDto.from(save(listing, ticketId), imageStorage, memberId);
    }

    /**
     * 등록가를 바꾼다. 매물을 올린 판매자 본인만 할 수 있다.
     *
     * <p>검사 순서는 먼저 걸리는 것 하나만 응답한다.
     *
     * <ol>
     *   <li>운영 시간 <b>밖</b>인가 → 409. 거래가 열려 있는 동안 가격은 고정이다 — 구매자가 목록에서 본
     *       값이 상세와 결제까지 그대로여야 한다. 바꾼 가격은 다음 창에 올라간다</li>
     *   <li>매물이 있는가 → 404</li>
     *   <li>내가 올린 매물인가 → 403</li>
     *   <li>새 가격이 정가 이하인가 → 400</li>
     *   <li>아직 {@code LISTED} 인가 → 409. <b>조회가 아니라 전이의 결과로 판정한다</b></li>
     * </ol>
     *
     * <p>권한 판정은 {@code TicketOwnershipService} 가 아니라 {@code sellerMemberId} 로 한다. 등록과 기준이
     * 다른 것이 의도다 — 등록은 "지금 이 티켓의 주인인가" 를 묻지만 여기서는 "이 매물을 올린 사람인가"
     * 를 묻는다. 취소({@link #cancel})와 같은 기준이고, 매물을 올린 뒤 소유가 바뀌는 경로는
     * 체결뿐인데 그때는 매물이 {@code SOLD} 라 4번에서 막힌다.
     *
     * <p>정가 기준은 <b>등록 시점에 잡힌 스냅샷</b>({@code face_value})이지 지금의
     * {@code Section.price} 가 아니다. 매물이 열린 뒤 구역 가격이 바뀌어도 그 매물의 판정 기준은
     * 흔들리지 않아야 한다({@code TicketListing} 주석). 그래서 여기서는 구역을 읽지도 않는다.
     *
     * <p>4번을 5번보다 앞에 두는 이유는 등록({@link #register})과 반대로 보이지만 사정이 다르다.
     * 등록의 409("이미 등록 중")는 가격을 고쳐도 결과가 같아 먼저 알려야 하는 것이고, 여기 4번은
     * 판매자 확인을 위해 이미 읽어 둔 행만으로 끝나는 검사다. 5번은 경쟁 상태라 UPDATE 를
     * 돌려 봐야만 알 수 있으므로 순서를 바꿀 여지가 없다.
     *
     * <p>바뀐 값이 없어도(같은 가격을 다시 보내도) 그대로 UPDATE 한다. 재시도가 안전해야 해서
     * 절댓값을 받는 API 이고, 같은 값이면 {@code updatedAt} 만 움직인다.
     *
     * <p>온체인 가격 갱신은 아직 부르지 않는다 - {@code listPrice}는 컨트랙트에도 있지만 갱신
     * 엔트리포인트가 없다. 등록가 자체는 항상 정가 이하로만 열리므로 당장 급한 정합성은 아니다.
     */
    @Transactional
    public ListingDetailResponseDto updatePrice(Long listingId,
                                                UpdateListingPriceRequestDto request,
                                                Long memberId) {
        marketHoursService.requireClosed();

        TicketListing listing = ticketListingRepository.findById(listingId)
                .orElseThrow(() -> new ListingNotFoundException(listingId));
        if (!listing.isSeller(memberId)) {
            throw new NotListingSellerException(listingId);
        }

        long price = request.price();
        // 지금의 구역 가격이 아니라 등록 시점에 박아 둔 스냅샷이다. 위 주석을 본다.
        long listedSectionPrice = listing.getFaceValue();
        if (price > listedSectionPrice) {
            throw new ListPriceExceedsFacePriceException(price, listedSectionPrice);
        }

        if (ticketListingRepository.updatePriceIfListed(listingId, price, LocalDateTime.now(clock)) == 0) {
            throw new ListingAlreadyClosedException(listingId);
        }

        // 조건부 UPDATE 가 영속성 컨텍스트를 비우므로 위에서 읽은 매물은 이미 옛 가격을 들고 있다.
        // 응답이 공연·공연장·구역을 쓰므로 상세용 조회로 다시 읽는다.
        TicketListing updated = ticketListingRepository.findDetailById(listingId)
                .orElseThrow(() -> new ListingNotFoundException(listingId));

        return ListingDetailResponseDto.from(updated, imageStorage, memberId);
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
     * <p><b>운영 시간을 보지 않는다.</b> 내 매물을 내리는 것은 언제든 가능해야 한다 — 닫힌 마켓에
     * 매물이 남아 있는 상태를 판매자가 다음 창까지 풀 수 없으면 안 된다.
     *
     * <p><b>취소 페널티는 없다.</b> 차감 규칙(D-7 100% / 하루 전 80% / 당일 10%)이 기획 미확정이라
     * 넣지 않았다. 정해지면 이 메서드가 잔액을 건드리게 되고 응답이 204 가 아니게 된다.
     *
     * <p>DB 취소가 확정된 뒤에 온체인 {@code delistFor}를 부르고 {@code ticket.markDelisted()}로 상태를 되돌린다.
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

        Ticket ticket = ticketRepository.findById(listing.getTicketId())
                .orElseThrow(() -> new TicketNotFoundException(listing.getTicketId()));
        if (blockchainProperties.hasRealAdminPrivateKey()) {
            ticketNftClient.delistFor(ticket.getTokenId(), walletService.getAddress(memberId));
        } else {
            log.debug("체인 미연결 - delistFor 를 건너뛴다 (listingId={})", listingId);
        }
        ticket.markDelisted();
    }

    /**
     * 정가 이하 판정의 기준값.
     *
     * <p>공연 전체 단일가가 아니라 이 티켓이 속한 <b>구역</b>의 정가다({@code Section.price}) -
     * 예매 결제·환불도 이제 전부 구역 가격 기준이므로({@code ReservationSettlementRunner},
     * {@code ReservationServiceImpl.cancel}) 재판매 상한도 같은 기준이어야 한다.
     *
     * <p>{@code Section.price}는 {@code nullable = false}라 여기서 별도로 없음을 검사하지
     * 않는다 - 이미 발행(OWNED)된 티켓이라는 것 자체가 그 좌석의 구역이 존재하고 가격이 있다는
     * 것을 보장한다.
     */
    private long sectionPriceOf(Section section) {
        return section.getPrice();
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
