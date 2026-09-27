package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.global.config.blockchain.BlockchainProperties;

import lombok.extern.slf4j.Slf4j;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.stereotype.Component;

import java.math.BigInteger;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

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
 *
 * <p><b>이 클래스 자체는 {@code @Transactional}이 아니다.</b> ON_SALE 공연 수십 건을 하나의
 * 트랜잭션 안에서 순차적으로 온체인 등록하면(공연 하나당 실제 네트워크 왕복이 있어 수십 초~수 분이
 * 걸릴 수 있다) 그 긴 트랜잭션이 {@code concert} 테이블 행을 물고 있는 동안
 * {@code ConcertStatusScheduler}(1분마다 도는 별도 스케줄러)가 같은 테이블에 조건부 UPDATE를
 * 시도하다 잠금 대기로 막힐 수 있다. 그래서 실제 DB 작업은 전부 {@link ProdShowRegistrar}(공연
 * 하나당 트랜잭션 하나)와 {@link ProdCatalogAccountSeeder}(계정·데모 티켓마다 트랜잭션 하나)에
 * 위임하고, 여기서는 그 호출들을 순서대로 나열만 한다.
 */
@Slf4j
@Component
@Profile("prod")
public class ProdCatalogSeeder implements ApplicationRunner {

    private final ConcertRepository concertRepository;
    private final VenueSeatCatalogSeeder venueSeatCatalogSeeder;
    private final SectionRepository sectionRepository;
    private final BlockchainProperties blockchainProperties;
    private final ProdShowRegistrar showRegistrar;
    private final ProdCatalogAccountSeeder accountSeeder;
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
                              BlockchainProperties blockchainProperties,
                              ProdShowRegistrar showRegistrar,
                              ProdCatalogAccountSeeder accountSeeder,
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
        this.blockchainProperties = blockchainProperties;
        this.showRegistrar = showRegistrar;
        this.accountSeeder = accountSeeder;
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
     * 관리자 계정이 이미 있으면 아무것도 하지 않는다. {@code concertRepository.count() > 0}로는 판단할
     * 수 없다 - {@code seed-concerts.sql}이 {@code ApplicationRunner}보다 먼저 48건을 무조건 넣어 두기
     * 때문에, 그 값은 이 시더가 실제로 실행됐는지와 무관하게 매 기동 항상 0보다 크다. 그래서 이 시더가
     * 직접 만드는 것 중 가장 확실한 신호인 관리자 로그인 계정 존재 여부로 가드한다
     * ({@link ProdCatalogAccountSeeder#adminAlreadyExists}).
     */
    @Override
    public void run(ApplicationArguments args) {
        Long venueId = venueSeatCatalogSeeder.seedVenueAndSeats();

        if (accountSeeder.adminAlreadyExists(adminUsername)) {
            log.info("운영 카탈로그 시드용 관리자 계정이 이미 있어 나머지 시드를 건너뛴다.");
            return;
        }

        if (!blockchainProperties.hasRealAdminPrivateKey()) {
            // ADMIN_PRIVATE_KEY는 infra 변수 검증에서 항상 실값을 요구하지만, 방화벽 등으로 체인에
            // 닿지 못하는 상황에서도 공연장·구역·좌석은 이미 채워졌으니 기동 자체는 실패시키지 않는다.
            log.warn("blockchain.admin-private-key 가 더미 값이라 운영 카탈로그의 계정 생성·온체인 등록을 건너뛴다.");
            return;
        }

        List<Section> sections = sectionRepository.findAllByVenueIdOrderByIdAsc(venueId);
        List<BigInteger> sectionPrices = sections.stream()
                .map(section -> BigInteger.valueOf(section.getPrice()))
                .toList();
        BigInteger totalSeats = BigInteger.valueOf(VenueSeatCatalogSeeder.totalSeatCount());

        Member organizer = accountSeeder.seedOrganizer(organizerPhone, organizerName, organizerNickname);

        // SCHEDULED 도 여기서 등록한다. openScheduled 는 organizer 와 showId 가 있어야 여는데 운영에서
        // registerShow 를 부르는 곳은 이 시더뿐이라, 빼면 오픈 시각이 와도 영영 열리지 않는다.
        // 등록은 상태를 바꾸지 않으므로 오픈 전 공연은 SCHEDULED 로 남는다. 스케줄러가 기동 즉시
        // ON_SALE 을 CLOSED 로 바꿀 수 있어 status 로는 거르지 않고 CANCELED 만 뺀다.
        // 시각이 비면 registerOne 에서 NPE 가 나 기동이 죽으므로 거른다. 재기동 시 중복 등록은 isReadyForBooking 이 막는다.
        List<Concert> registrable = concertRepository.findAll().stream()
                .filter(concert -> concert.getStatus() != ConcertStatus.CANCELED)
                .filter(concert -> concert.getOpenAt() != null && concert.getStartDate() != null)
                .filter(concert -> !concert.isReadyForBooking())
                .toList();

        List<Concert> registered = new ArrayList<>(registrable.size());
        for (Concert concert : registrable) {
            if (showRegistrar.registerOne(concert.getId(), organizer, sectionPrices, totalSeats)) {
                registered.add(concert);
            }
        }
        log.info("운영 카탈로그: 공연 {}/{}건을 체인에 등록했다.", registered.size(), registrable.size());

        Member admin = accountSeeder.seedAdmin(adminPhone, adminName, adminNickname, adminUsername, adminPassword);

        // 소장품 데모는 "이미 입장까지 마친" 티켓이어야 말이 되므로, 등록에 성공한 것들 중에서도
        // 종료 시각이 이미 지난 공연만 고른다 - 아직 시작도 안 한 공연에 USED 티켓을 붙이면
        // 화면상 앞뒤가 안 맞는다.
        LocalDateTime now = LocalDateTime.now(clock);
        Optional<Concert> alreadyEnded = registered.stream()
                .filter(concert -> concert.getEndDate() != null && concert.getEndDate().isBefore(now))
                .findFirst();

        if (alreadyEnded.isEmpty()) {
            log.warn("관리자 시드 - 이미 종료된 공연이 없어 소장품용 티켓은 건너뛴다.");
        } else {
            Long ticketId = accountSeeder.seedUsedTicket(sections, alreadyEnded.get().getId(), admin);
            // goods_upload.ticket_id 가 NOT NULL 이라 티켓이 생긴 경우에만 대장을 적는다.
            accountSeeder.seedGoodsUploads(admin.getId(), ticketId);
        }

        log.info("운영 시드: 관리자 계정을 만들었다. id={}", adminUsername);
    }
}
