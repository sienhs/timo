package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.blockchain.ContractCallException;
import com.ssafy.timo.domain.blockchain.ContractClient;
import com.ssafy.timo.domain.blockchain.MintResult;
import com.ssafy.timo.domain.blockchain.ShowRegistryClient;
import com.ssafy.timo.domain.blockchain.TicketNftClient;
import com.ssafy.timo.domain.blockchain.TicketVaultClient;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.ticket.service.TicketEnteredEvent;
import com.ssafy.timo.domain.wallet.service.WalletService;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;

import jakarta.persistence.EntityManager;

import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigInteger;
import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

/**
 * 운영 카탈로그 부트스트랩. {@code spring.sql.init}가 기동 초입에 미리 넣어 둔
 * {@code seed-venue.sql}(공연장 1건) · {@code seed-concerts.sql}(아티스트·공연·상세이미지, 48건)
 * 위에서, SQL로는 할 수 없는 나머지 - 구역·좌석(사다리꼴 배치는 Java 코드로만 표현된다), 지갑이
 * 필요한 계정, 실제 서명이 필요한 온체인 등록 - 을 채운다.
 *
 * <p>{@code LocalDataSeeder}(local·demo)와는 성격이 완전히 다른 데이터라 서로 갈라 뒀다 - 여긴 실제
 * 발표에 쓰는 진짜 콘텐츠고, 가짜 회원 180명·판매/선점 시늉·양도 매물 같은 로컬 전용 더미는 여기
 * 없다. 공연장·구역·좌석 생성만 {@link VenueSeatCatalogSeeder}로 공유한다 - 사다리꼴 배치 로직이
 * 양쪽에 복사되면 하나만 고치고 하나는 놓치는 위험이 생기기 때문이다.
 *
 * <p>주최자·관리자 계정은 코드에 하드코딩하지 않고 {@code application-prod.yml}(→ 환경변수)에서
 * 받는다 - 특히 관리자는 로그인 가능한 계정이라 비밀번호가 저장소에 남으면 안 된다.
 */
@Slf4j
@Component
@Profile("prod")
public class ProdCatalogSeeder implements ApplicationRunner {

    private final ConcertRepository concertRepository;
    private final VenueSeatCatalogSeeder venueSeatCatalogSeeder;
    private final SectionRepository sectionRepository;
    private final SeatRepository seatRepository;
    private final MemberRepository memberRepository;
    private final LoginInfoRepository loginInfoRepository;
    private final PasswordEncoder passwordEncoder;
    private final WalletService walletService;
    private final ShowRegistryClient showRegistryClient;
    private final TicketVaultClient ticketVaultClient;
    private final TicketNftClient ticketNftClient;
    private final ReservationRepository reservationRepository;
    private final TicketRepository ticketRepository;
    private final BlockchainProperties blockchainProperties;
    private final ApplicationEventPublisher eventPublisher;
    private final EntityManager entityManager;
    private final Clock clock;

    private final String organizerPhone;
    private final String organizerName;
    private final String organizerNickname;
    private final String adminPhone;
    private final String adminName;
    private final String adminNickname;
    private final String adminUsername;
    private final String adminPassword;

    public ProdCatalogSeeder(ConcertRepository concertRepository,
                              VenueSeatCatalogSeeder venueSeatCatalogSeeder,
                              SectionRepository sectionRepository,
                              SeatRepository seatRepository,
                              MemberRepository memberRepository,
                              LoginInfoRepository loginInfoRepository,
                              PasswordEncoder passwordEncoder,
                              WalletService walletService,
                              ShowRegistryClient showRegistryClient,
                              TicketVaultClient ticketVaultClient,
                              TicketNftClient ticketNftClient,
                              ReservationRepository reservationRepository,
                              TicketRepository ticketRepository,
                              BlockchainProperties blockchainProperties,
                              ApplicationEventPublisher eventPublisher,
                              EntityManager entityManager,
                              Clock clock,
                              @Value("${seed.organizer.phone-number}") String organizerPhone,
                              @Value("${seed.organizer.name}") String organizerName,
                              @Value("${seed.organizer.nickname}") String organizerNickname,
                              @Value("${seed.admin.phone-number}") String adminPhone,
                              @Value("${seed.admin.name}") String adminName,
                              @Value("${seed.admin.nickname}") String adminNickname,
                              @Value("${seed.admin.username}") String adminUsername,
                              @Value("${seed.admin.password}") String adminPassword) {
        this.concertRepository = concertRepository;
        this.venueSeatCatalogSeeder = venueSeatCatalogSeeder;
        this.sectionRepository = sectionRepository;
        this.seatRepository = seatRepository;
        this.memberRepository = memberRepository;
        this.loginInfoRepository = loginInfoRepository;
        this.passwordEncoder = passwordEncoder;
        this.walletService = walletService;
        this.showRegistryClient = showRegistryClient;
        this.ticketVaultClient = ticketVaultClient;
        this.ticketNftClient = ticketNftClient;
        this.reservationRepository = reservationRepository;
        this.ticketRepository = ticketRepository;
        this.blockchainProperties = blockchainProperties;
        this.eventPublisher = eventPublisher;
        this.entityManager = entityManager;
        this.clock = clock;
        this.organizerPhone = organizerPhone;
        this.organizerName = organizerName;
        this.organizerNickname = organizerNickname;
        this.adminPhone = adminPhone;
        this.adminName = adminName;
        this.adminNickname = adminNickname;
        this.adminUsername = adminUsername;
        this.adminPassword = adminPassword;
    }

    /**
     * 공연이 하나라도 있으면 아무것도 하지 않는다. {@code seed-concerts.sql}이 이미 48건을 넣어 둔
     * 뒤라면(정상적인 매 기동), 이 가드가 바로 걸려 아래 온체인 등록·계정 생성이 반복되지 않는다 -
     * 실제로 무언가 하는 건 RDS가 완전히 빈 최초 1회뿐이다.
     */
    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        long existing = concertRepository.count();
        if (existing > 0) {
            log.info("공연이 이미 {}건 있어 운영 카탈로그 시드를 건너뛴다.", existing);
            return;
        }

        Long venueId = venueSeatCatalogSeeder.seedVenueAndSeats();

        if (!blockchainProperties.hasRealAdminPrivateKey()) {
            log.warn("blockchain.admin-private-key 가 더미 값이라 운영 카탈로그의 계정 생성·온체인 등록을 건너뛴다.");
            return;
        }

        List<Section> sections = sectionRepository.findAllByVenueIdOrderByIdAsc(venueId);
        List<BigInteger> sectionPrices = sections.stream()
                .map(section -> BigInteger.valueOf(section.getPrice()))
                .toList();
        BigInteger totalSeats = BigInteger.valueOf(VenueSeatCatalogSeeder.totalSeatCount());

        Member organizer = seedOrganizer();

        List<Concert> onSaleConcerts = concertRepository.findAll().stream()
                .filter(concert -> concert.getStatus() == ConcertStatus.ON_SALE)
                .toList();
        List<Concert> registered = registerOnChain(onSaleConcerts, organizer, sectionPrices, totalSeats);
        log.info("운영 카탈로그: 공연 {}/{}건을 체인에 등록했다.", registered.size(), onSaleConcerts.size());

        Member admin = seedAdmin();
        seedAdminUsedTicket(sections, registered, admin);
    }

    /**
     * 온체인 등록을 대신 서명하는 admin 지갑과는 별개로, {@code chargeForBooking} 이 예매 대금을
     * 적립할 실제 지갑 주소가 필요해 회원+지갑을 만든다.
     */
    private Member seedOrganizer() {
        Member organizer = memberRepository.save(Member.builder()
                .phoneNumber(organizerPhone)
                .name(organizerName)
                .nickname(organizerNickname)
                .build());
        walletService.createWallet(organizer);
        return organizer;
    }

    /**
     * 소장품(굿즈) 화면을 발표 자리에서 바로 보여줄 수 있는 로그인 계정. {@code Member.builder()}가
     * 항상 {@code Role.USER}로 고정해서, 저장 직후 벌크 업데이트로 {@code ADMIN}으로 바꾼다.
     */
    private Member seedAdmin() {
        Member admin = memberRepository.save(Member.builder()
                .phoneNumber(adminPhone)
                .name(adminName)
                .nickname(adminNickname)
                .build());
        entityManager.createQuery(
                        "update Member m set m.role = com.ssafy.timo.domain.member.entity.Role.ADMIN where m.id = :id")
                .setParameter("id", admin.getId())
                .executeUpdate();

        loginInfoRepository.save(LoginInfo.builder()
                .member(admin)
                .username(adminUsername)
                .passwordHash(passwordEncoder.encode(adminPassword))
                .build());

        walletService.createWallet(admin);
        return admin;
    }

    /**
     * {@code ON_SALE} 공연을 실제 체인에 등록한다. 공연마다 독립적으로 실패를 잡는다 - 한 공연의
     * 체인 등록이 실패해도 나머지 공연과 이미 넣은 카탈로그는 그대로 살아 있어야 한다.
     *
     * <p>등록에 실패한 공연은 {@code SCHEDULED}로 되돌린다. {@code ON_SALE}인데
     * {@code isReadyForBooking()}이 false인 상태를 남기면 {@code ReservationServiceImpl.create()}가
     * 그걸 불변식 위반(500)으로 보고 던지기 때문에, "체인 미등록"은 항상 "아직 판매 전"(409)으로
     * 보여야 한다({@code LocalDataSeeder}와 같은 이유).
     */
    private List<Concert> registerOnChain(List<Concert> onSaleConcerts, Member organizer,
                                          List<BigInteger> sectionPrices, BigInteger totalSeats) {
        List<Concert> registered = new ArrayList<>(onSaleConcerts.size());
        for (Concert concert : onSaleConcerts) {
            try {
                long saleOpenTime = concert.getOpenAt().atZone(clock.getZone()).toEpochSecond();
                long showTime = concert.getStartDate().atZone(clock.getZone()).toEpochSecond();
                BigInteger showId = showRegistryClient.registerShow(
                        sectionPrices, totalSeats, saleOpenTime, showTime, "prod-seed:" + concert.getTitle());

                concert.prepareForSale(organizer);
                concert.confirmRegistered(showId);
                registered.add(concert);
            } catch (ContractCallException e) {
                log.warn("공연 '{}' 온체인 등록 실패, SCHEDULED 로 되돌린다 - 체인 접근(방화벽·키)을 확인하라",
                        concert.getTitle(), e);
                revertToScheduled(concert.getId());
            }
        }
        return registered;
    }

    private void revertToScheduled(Long concertId) {
        entityManager.createQuery(
                        "update Concert c set c.status = com.ssafy.timo.domain.concert.entity.ConcertStatus.SCHEDULED "
                                + "where c.id = :id")
                .setParameter("id", concertId)
                .executeUpdate();
    }

    /**
     * 관리자 계정에 "이미 입장 완료"된 진짜 티켓을 하나 쥐여준다 - 첫 번째 구역의 첫 번째 좌석,
     * 온체인 등록에 성공한 첫 번째 공연으로 고정한다(재기동해도 항상 같은 자리).
     *
     * <p>{@code GoodsTicketGuard.requireUsedTicket}은 DB의 {@code ticket.status}만 보지만,
     * 이 티켓은 지어낸 값이 아니라 실제 체인 흐름(충전 → 차감 → 발행 → 입장 기록)을 그대로 태운다 -
     * 진짜 tokenId로 발급되고, 온체인 {@code markUsed}까지 반영된다.
     */
    private void seedAdminUsedTicket(List<Section> sections, List<Concert> registeredOnSaleConcerts, Member admin) {
        if (registeredOnSaleConcerts.isEmpty()) {
            log.warn("관리자 시드 - 온체인 등록된 공연이 없어 소장품용 티켓은 건너뛴다.");
            return;
        }

        Concert concert = registeredOnSaleConcerts.get(0);
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

        log.info("운영 시드: 관리자 계정을 만들었다. id={} (소장품용 tokenId={})", adminUsername, minted.tokenId());
    }
}
