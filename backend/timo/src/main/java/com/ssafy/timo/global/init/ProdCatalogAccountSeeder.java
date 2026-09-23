package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.blockchain.ContractClient;
import com.ssafy.timo.domain.blockchain.MintResult;
import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.ticket.service.TicketEnteredEvent;
import com.ssafy.timo.domain.wallet.service.WalletService;

import jakarta.persistence.EntityManager;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigInteger;
import java.util.List;
import java.util.UUID;

/**
 * {@code ProdCatalogSeeder}가 위임하는 계정·데모 티켓 생성. 온체인 등록({@link ProdShowRegistrar})과
 * 같은 이유로 별도 빈이다 - 각 메서드가 자기만의 짧은 트랜잭션을 갖게 해서, 공연 수십 건을 순차
 * 등록하는 긴 흐름 중간에 이 호출들이 껴 있어도 {@code concert} 테이블을 오래 물고 있지 않는다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
class ProdCatalogAccountSeeder {

    private final MemberRepository memberRepository;
    private final LoginInfoRepository loginInfoRepository;
    private final PasswordEncoder passwordEncoder;
    private final WalletService walletService;
    private final ConcertRepository concertRepository;
    private final SeatRepository seatRepository;
    private final ReservationRepository reservationRepository;
    private final TicketRepository ticketRepository;
    private final TicketVaultClient ticketVaultClient;
    private final TicketNftClient ticketNftClient;
    private final ApplicationEventPublisher eventPublisher;
    private final EntityManager entityManager;

    /**
     * 온체인 등록을 대신 서명하는 admin 지갑과는 별개로, {@code chargeForBooking} 이 예매 대금을
     * 적립할 실제 지갑 주소가 필요해 회원+지갑을 만든다.
     */
    @Transactional
    Member seedOrganizer(String phone, String name, String nickname) {
        Member organizer = memberRepository.save(Member.builder()
                .phoneNumber(phone)
                .name(name)
                .nickname(nickname)
                .build());
        walletService.createWallet(organizer);
        return organizer;
    }

    /**
     * 소장품(굿즈) 화면을 발표 자리에서 바로 보여줄 수 있는 로그인 계정. {@code Member.builder()}가
     * 항상 {@code Role.USER}로 고정해서, 저장 직후 벌크 업데이트로 {@code ADMIN}으로 바꾼다.
     */
    @Transactional
    Member seedAdmin(String phone, String name, String nickname, String username, String password) {
        Member admin = memberRepository.save(Member.builder()
                .phoneNumber(phone)
                .name(name)
                .nickname(nickname)
                .build());
        entityManager.createQuery(
                        "update Member m set m.role = com.ssafy.timo.domain.member.entity.Role.ADMIN where m.id = :id")
                .setParameter("id", admin.getId())
                .executeUpdate();

        loginInfoRepository.save(LoginInfo.builder()
                .member(admin)
                .username(username)
                .passwordHash(passwordEncoder.encode(password))
                .build());

        walletService.createWallet(admin);
        return admin;
    }

    /**
     * 관리자 계정에 "이미 입장 완료"된 진짜 티켓을 하나 쥐여준다 - 첫 번째 구역의 첫 번째 좌석,
     * 온체인 등록에 성공한 공연 중 첫 번째로 고정한다(재기동해도 항상 같은 자리).
     *
     * <p>{@code GoodsTicketGuard.requireUsedTicket}은 DB의 {@code ticket.status}만 보지만,
     * 이 티켓은 지어낸 값이 아니라 실제 체인 흐름(충전 → 차감 → 발행 → 입장 기록)을 그대로 태운다 -
     * 진짜 tokenId로 발급되고, 온체인 {@code markUsed}까지 반영된다.
     */
    @Transactional
    void seedUsedTicket(List<Section> sections, Long concertId, Member admin) {
        Concert concert = concertRepository.getReferenceById(concertId);
        Section section = sections.get(0);
        Seat seat = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId()).get(0);
        int sectionIndex = 0;

        String adminAddress = walletService.getAddress(admin.getId());
        String organizerAddress = walletService.getAddress(concert.getOrganizer().getId());
        BigInteger price = BigInteger.valueOf(section.getPrice());

        byte[] depositRef = ContractClient.keccak256("prod-seed-admin-deposit-" + UUID.randomUUID());
        ticketVaultClient.deposit(adminAddress, price, depositRef);

        byte[] orderId = ContractClient.keccak256("prod-seed-admin-order-" + UUID.randomUUID());
        ticketVaultClient.chargeForBooking(adminAddress, organizerAddress, price, orderId);

        MintResult minted = ticketNftClient.mintTicket(
                adminAddress, concert.getShowId(), BigInteger.valueOf(seat.getId()), sectionIndex);

        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(admin)
                .seat(seat)
                .build());

        Ticket ticket = Ticket.builder().reservation(reservation).build();
        ticket.markMinted(minted.tokenId(), minted.transactionHash());
        ticket.markUsed();
        ticketRepository.save(ticket);

        // 실제 게이트 스캔과 같은 경로로 온체인 markUsed를 비동기로 반영한다(TicketEntryOnChainService).
        eventPublisher.publishEvent(new TicketEnteredEvent(ticket.getId(), minted.tokenId()));

        log.info("운영 시드: 관리자 계정의 소장품용 티켓을 만들었다. tokenId={}", minted.tokenId());
    }
}
