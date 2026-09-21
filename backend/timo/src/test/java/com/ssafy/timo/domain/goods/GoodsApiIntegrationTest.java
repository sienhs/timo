package com.ssafy.timo.domain.goods;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.hamcrest.Matchers.contains;
import static org.hamcrest.Matchers.containsInAnyOrder;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.artist.repository.ArtistRepository;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.goods.dto.CollectibleConcertRow;
import com.ssafy.timo.domain.goods.dto.CreateGoodsCommand;
import com.ssafy.timo.domain.goods.dto.GoodsCreateResult;
import com.ssafy.timo.domain.goods.entity.Goods;
import com.ssafy.timo.domain.goods.entity.GoodsEffect;
import com.ssafy.timo.domain.goods.exception.GoodsAlreadyExistsException;
import com.ssafy.timo.domain.goods.exception.GoodsErrorCode;
import com.ssafy.timo.domain.goods.exception.GoodsInvalidLayersException;
import com.ssafy.timo.domain.goods.exception.GoodsTicketNotOwnedException;
import com.ssafy.timo.domain.goods.exception.GoodsTicketNotUsedException;
import com.ssafy.timo.domain.goods.repository.GoodsRepository;
import com.ssafy.timo.domain.goods.service.GoodsService;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.reservation.repository.ReservationRepository;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatPosition;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.seat.repository.SeatRepository;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.transfer.entity.TicketListing;
import com.ssafy.timo.domain.transfer.entity.TicketTrade;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.transfer.repository.TicketTradeRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.global.exception.BusinessException;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import java.math.BigInteger;
import java.time.LocalDateTime;
import com.ssafy.timo.domain.ticket.dto.MyTicketRow;
import java.util.List;
import org.springframework.data.domain.Pageable;
import java.util.stream.IntStream;
import org.hibernate.SessionFactory;
import org.hibernate.stat.Statistics;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * 굿즈 도메인 통합 테스트 — 생성 규칙(서비스)과 조회 API 셋.
 *
 * <p>생성은 컨트롤러가 아직 없어 {@link GoodsService#create} 를 직접 부른다. 201/200 은
 * {@code GoodsCreateResult.created()} 로 본다. 소유 판정이 네이티브 쿼리라 여기서만 검증된다 —
 * 양도받은 티켓의 구매자는 만들 수 있고 원 예매자는 못 만드는 것이 핵심이다.
 *
 * <p>소장품 공연 목록이 티켓 수에 비례해 쿼리를 내지 않는지는 Hibernate 통계로 센다. 설정 파일을
 * 건드리지 않으려고 테스트 안에서 런타임에 켠다.
 */
@IntegrationTest
class GoodsApiIntegrationTest {

    private static final String COLLECTIBLE_CONCERTS_PATH = "/api/v1/collectibles/concerts";
    private static final String MY_GOODS_PATH = "/api/v1/goods/me";
    private static final String GOODS_PATH = "/api/v1/goods/{goodsId}";
    private static final int SEAT_PRICE = 150_000;

    @Autowired
    private MockMvc mvc;

    @Autowired
    private VenueRepository venueRepository;

    @Autowired
    private SectionRepository sectionRepository;

    @Autowired
    private SeatRepository seatRepository;

    @Autowired
    private ConcertRepository concertRepository;

    @Autowired
    private ArtistRepository artistRepository;

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private TicketRepository ticketRepository;

    @Autowired
    private TicketListingRepository ticketListingRepository;

    @Autowired
    private TicketTradeRepository ticketTradeRepository;

    @Autowired
    private GoodsRepository goodsRepository;

    @Autowired
    private GoodsService goodsService;

    @Autowired
    private EntityManager em;

    private final JsonMapper mapper = JsonMapper.builder().build();

    private Section section;
    private List<Seat> seats;
    private Member alice;
    private Member bob;
    private Venue venue;
    private Artist artist;

    @BeforeEach
    void setUpFixtures() {
        venue = venueRepository.save(Venue.builder()
                .name("고척돔")
                .address("서울시 구로구 경인로 430")
                .totalSeatCount(16000)
                .build());
        section = saveSection(venue);
        seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());
        artist = artistRepository.save(Artist.builder().name("아이유").build());

        alice = saveMember("01011112222", "앨리스");
        bob = saveMember("01033334444", "밥");
    }

    @AfterEach
    void clearRequester() {
        Authenticated.clear();
    }

    // ---------------------------------------------------------------- 생성

    @Test
    @DisplayName("입장 완료한 내 티켓이면 만들어지고, 공연과 스냅샷은 티켓에서 채운다")
    void createFromUsedTicket() {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        ticket.markUsed();
        em.flush();

        GoodsCreateResult result = goodsService.create(alice.getId(), ticket.getId(), command("c-1"));

        assertThat(result.created()).isTrue();
        assertThat(result.goods().ticketId()).isEqualTo(ticket.getId());
        assertThat(result.goods().concertId()).isEqualTo(ticket.getReservation().getConcert().getId());
        assertThat(result.goods().concertSnapshot().get("title").stringValue()).isEqualTo("아이유 콘서트");
        assertThat(result.goods().concertSnapshot().get("artist").stringValue()).isEqualTo("아이유");
        assertThat(result.goods().concertSnapshot().get("venue").stringValue()).isEqualTo("고척돔");
        assertThat(result.goods().backgroundUrl()).isEqualTo("https://cdn.test.timo.io/bg.png");
        assertThat(goodsRepository.count()).isEqualTo(1);

        // 저장된 JSON 이 MySQL json 컬럼에서 그대로 돌아온다.
        em.clear();
        Goods saved = goodsRepository.findById(result.goods().goodsId()).orElseThrow();
        assertThat(saved.getMember().getId()).isEqualTo(alice.getId());
        assertThat(mapper.readTree(saved.getPersonLayers()).get(1).get("layerOrder").asInt()).isEqualTo(1);
        assertThat(saved.getBackgroundFraming()).isNull();
    }

    @Test
    @DisplayName("입장 전(OWNED) 티켓이면 409 GOODS_TICKET_NOT_USED")
    void ownedTicketRejected() {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        em.flush();

        assertThatThrownBy(() -> goodsService.create(alice.getId(), ticket.getId(), command("c-1")))
                .isInstanceOf(GoodsTicketNotUsedException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorCode())
                        .isEqualTo(GoodsErrorCode.GOODS_TICKET_NOT_USED));
        assertThat(goodsRepository.count()).isZero();
    }

    @Test
    @DisplayName("남의 입장 완료 티켓은 404 - 존재를 알리지 않는다")
    void othersTicketHidden() {
        Ticket ticket = book(bob, 0, "아이유 콘서트");
        ticket.markUsed();
        em.flush();

        assertThatThrownBy(() -> goodsService.create(alice.getId(), ticket.getId(), command("c-1")))
                .isInstanceOf(GoodsTicketNotOwnedException.class)
                .satisfies(e -> assertThat(((BusinessException) e).getErrorCode().getStatus().value())
                        .isEqualTo(404));
        // 없는 티켓도 같은 답이다.
        assertThatThrownBy(() -> goodsService.create(alice.getId(), 999_999L, command("c-1")))
                .isInstanceOf(GoodsTicketNotOwnedException.class);
    }

    @Test
    @DisplayName("양도받아 입장한 티켓은 구매자가 만들고, 원 예매자는 못 만든다")
    void transferredTicketBelongsToBuyer() {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        trade(ticket, alice, bob, LocalDateTime.now().minusDays(1));
        markUsedAfterTrade(ticket);

        assertThatThrownBy(() -> goodsService.create(alice.getId(), ticket.getId(), command("c-1")))
                .isInstanceOf(GoodsTicketNotOwnedException.class);

        GoodsCreateResult result = goodsService.create(bob.getId(), ticket.getId(), command("c-1"));

        assertThat(result.created()).isTrue();
        em.clear();
        assertThat(goodsRepository.findById(result.goods().goodsId()).orElseThrow().getMember().getId())
                .isEqualTo(bob.getId());
    }

    @Test
    @DisplayName("같은 clientGoodsId 재전송은 저장하지 않고 기존 굿즈를 돌려준다(200)")
    void sameClientIdIsIdempotent() {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        ticket.markUsed();
        em.flush();
        GoodsCreateResult first = goodsService.create(alice.getId(), ticket.getId(), command("c-1"));

        GoodsCreateResult retry = goodsService.create(alice.getId(), ticket.getId(), command("c-1"));

        assertThat(retry.created()).isFalse();
        assertThat(retry.goods().goodsId()).isEqualTo(first.goods().goodsId());
        assertThat(goodsRepository.count()).isEqualTo(1);
    }

    @Test
    @DisplayName("이미 있는데 다른 clientGoodsId 면 409 GOODS_ALREADY_EXISTS")
    void differentClientIdConflicts() {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        ticket.markUsed();
        em.flush();
        goodsService.create(alice.getId(), ticket.getId(), command("c-1"));

        assertThatThrownBy(() -> goodsService.create(alice.getId(), ticket.getId(), command("c-2")))
                .isInstanceOf(GoodsAlreadyExistsException.class);
        assertThat(goodsRepository.count()).isEqualTo(1);
    }

    @Test
    @DisplayName("personLayers 가 3개이거나 layerOrder 가 겹치면 400")
    void invalidLayers() {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        ticket.markUsed();
        em.flush();

        JsonNode three = mapper.readTree("[{\"layerOrder\":0},{\"layerOrder\":1},{\"layerOrder\":2}]");
        JsonNode duplicated = mapper.readTree("[{\"layerOrder\":0},{\"layerOrder\":0}]");

        assertThatThrownBy(() -> goodsService.create(alice.getId(), ticket.getId(), command("c-1", three)))
                .isInstanceOf(GoodsInvalidLayersException.class);
        assertThatThrownBy(() -> goodsService.create(alice.getId(), ticket.getId(), command("c-1", duplicated)))
                .isInstanceOf(GoodsInvalidLayersException.class);
        assertThat(goodsRepository.count()).isZero();
    }

    // ---------------------------------------------------------------- 소장품 공연 목록

    @Test
    @DisplayName("입장 완료한 내 티켓만 나오고, 굿즈를 만든 것은 goodsId 가 채워진다")
    void collectibleConcerts() throws Exception {
        Ticket used = book(alice, 0, "만든 공연");
        used.markUsed();
        Ticket usedNoGoods = book(alice, 1, "아직 안 만든 공연");
        usedNoGoods.markUsed();
        book(alice, 2, "입장 전 공연");
        Ticket bobs = book(bob, 3, "밥의 공연");
        bobs.markUsed();
        em.flush();
        Long goodsId = goodsService.create(alice.getId(), used.getId(), command("c-1")).goods().goodsId();

        Authenticated.set(alice.getId());
        mvc.perform(get(COLLECTIBLE_CONCERTS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(2))
                .andExpect(jsonPath("$[*].ticketId",
                        containsInAnyOrder(used.getId().intValue(), usedNoGoods.getId().intValue())))
                .andExpect(jsonPath("$[?(@.ticketId == %d)].goodsId".formatted(used.getId()))
                        .value(goodsId.intValue()))
                .andExpect(jsonPath("$[?(@.ticketId == %d)].goodsId".formatted(usedNoGoods.getId()))
                        .value((Object) null))
                .andExpect(jsonPath("$[?(@.ticketId == %d)].title".formatted(used.getId())).value("만든 공연"))
                .andExpect(jsonPath("$[?(@.ticketId == %d)].artist".formatted(used.getId())).value("아이유"))
                .andExpect(jsonPath("$[?(@.ticketId == %d)].venue".formatted(used.getId())).value("고척돔"))
                .andExpect(jsonPath("$[?(@.ticketId == %d)].concertId".formatted(used.getId()))
                        .value(used.getReservation().getConcert().getId().intValue()))
                .andExpect(jsonPath("$[?(@.ticketId == %d)].thumbnailUrl".formatted(used.getId()))
                        .value("https://cdn.test.timo.io/poster.jpg"))
                .andExpect(jsonPath("$[?(@.ticketId == %d)].videoUrl".formatted(used.getId()))
                        .value((Object) null));
    }

    @Test
    @DisplayName("양도받아 입장한 티켓은 구매자 목록에 나오고 원 예매자 목록에서는 빠진다")
    void collectibleConcertsFollowTransfer() throws Exception {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        trade(ticket, alice, bob, LocalDateTime.now().minusDays(1));
        markUsedAfterTrade(ticket);

        Authenticated.set(alice.getId());
        mvc.perform(get(COLLECTIBLE_CONCERTS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(0));

        Authenticated.set(bob.getId());
        mvc.perform(get(COLLECTIBLE_CONCERTS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].ticketId").value(ticket.getId().intValue()));
    }

    @Test
    @DisplayName("소유 판정이 티켓 목록과 어긋나지 않는다 - 같은 SQL 조각을 쓰는지 교차로 본다")
    void ownershipMatchesTicketRepository() {
        // 세 쿼리가 같은 owner_member_id를 사용해도 기능별 조건이 다르므로
        // 여전히 갈릴 수 있다. 예전에 규칙이 네 군데에 복사돼 있던 자리라 교차로 못 박아 둔다.
        Ticket kept = book(alice, 0, "안 판 공연");
        kept.markUsed();
        Ticket notUsed = book(alice, 1, "아직 입장 전 공연");
        Ticket sold = book(alice, 2, "양도한 공연");
        em.flush();
        trade(sold, alice, bob, LocalDateTime.now().minusDays(1));
        markUsedAfterTrade(sold);
        em.clear();

        List<Long> aliceTickets = ticketRepository.findMyTickets(alice.getId(), Pageable.ofSize(50))
                .map(MyTicketRow::getTicketId)
                .toList();
        assertThat(aliceTickets).containsExactlyInAnyOrder(kept.getId(), notUsed.getId());

        // 소장품 목록은 그 집합에서 입장 완료만 남긴 것이어야 한다.
        assertThat(goodsRepository.findCollectibleConcerts(alice.getId()))
                .extracting(CollectibleConcertRow::getTicketId)
                .containsExactly(kept.getId());

        // 소유 판정도 같은 집합을 따라야 한다.
        assertThat(ticketRepository.existsByIdAndOwnerMemberId(kept.getId(), alice.getId())).isTrue();
        assertThat(ticketRepository.existsByIdAndOwnerMemberId(sold.getId(), alice.getId())).isFalse();
        assertThat(ticketRepository.existsByIdAndOwnerMemberId(sold.getId(), bob.getId())).isTrue();

        assertThat(ticketRepository.findMyTickets(bob.getId(), Pageable.ofSize(50))
                .map(MyTicketRow::getTicketId))
                .containsExactly(sold.getId());
    }

    @Test
    @DisplayName("양도된 티켓의 소장품 목록에 전 소유자의 굿즈 id 가 실리지 않는다")
    void collectibleConcertsHideOtherOwnersGoodsId() throws Exception {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        ticket.markUsed();
        em.flush();
        goodsService.create(alice.getId(), ticket.getId(), command("c-alice"));
        em.flush();
        // ListingService·PurchaseService 는 OWNED 만 거래하게 막으므로 이 순서는 API 로는 만들 수
        // 없다. 그래도 고정해 두는 이유는, 굿즈 조회가 남의 도메인 상태 규칙에 기대지 않아야 하기
        // 때문이다. 그쪽 규칙이 느슨해지면 이 테스트가 먼저 깨진다.
        trade(ticket, alice, bob, LocalDateTime.now());
        markUsedAfterTrade(ticket);
        em.flush();
        em.clear();

        Authenticated.set(bob.getId());
        mvc.perform(get(COLLECTIBLE_CONCERTS_PATH))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.length()").value(1))
                .andExpect(jsonPath("$[0].ticketId").value(ticket.getId().intValue()))
                .andExpect(jsonPath("$[0].goodsId").doesNotExist());
    }

    @Test
    @DisplayName("남이 만든 굿즈가 있는 티켓은 멱등 키가 같아도 409 다 - 그 굿즈를 돌려주지 않는다")
    void createRejectsWhenTicketGoodsBelongsToSomeoneElse() {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        ticket.markUsed();
        em.flush();
        goodsService.create(alice.getId(), ticket.getId(), command("same-key"));
        em.flush();
        trade(ticket, alice, bob, LocalDateTime.now());
        markUsedAfterTrade(ticket);
        em.flush();
        em.clear();

        // 멱등 재시도는 같은 사람의 같은 요청일 때만 성립한다. 소유자를 보지 않으면 앨리스의
        // 저장소 key 와 URL 이 밥에게 200 으로 나간다.
        assertThatThrownBy(() -> goodsService.create(bob.getId(), ticket.getId(), command("same-key")))
                .isInstanceOf(GoodsAlreadyExistsException.class);
    }

    @Test
    @DisplayName("쿼리 수가 티켓 수에 비례하지 않는다 - 굿즈 id 를 같은 문장에서 가져온다")
    void collectibleConcertsQueryCountIsFlat() throws Exception {
        Ticket one = book(alice, 0, "공연 1");
        one.markUsed();
        em.flush();
        goodsService.create(alice.getId(), one.getId(), command("c-1"));
        em.flush();
        em.clear();
        Authenticated.set(alice.getId());

        long withOneTicket = countStatements(() ->
                mvc.perform(get(COLLECTIBLE_CONCERTS_PATH))
                        .andExpect(jsonPath("$.length()").value(1)));

        for (int i = 1; i <= 4; i++) {
            Ticket more = book(alice, i, "공연 " + (i + 1));
            more.markUsed();
            em.flush();
            if (i % 2 == 0) {
                goodsService.create(alice.getId(), more.getId(), command("c-" + (i + 1)));
            }
        }
        em.flush();
        em.clear();

        long withFiveTickets = countStatements(() ->
                mvc.perform(get(COLLECTIBLE_CONCERTS_PATH))
                        .andExpect(jsonPath("$.length()").value(5)));

        assertThat(withFiveTickets).isEqualTo(withOneTicket);
    }

    // ---------------------------------------------------------------- 내 굿즈 목록·상세

    @Test
    @DisplayName("내 굿즈 목록은 최신 순이고 페이지가 잘린다")
    void myGoodsPagedNewestFirst() throws Exception {
        Ticket t1 = book(alice, 0, "공연 1");
        Ticket t2 = book(alice, 1, "공연 2");
        Ticket t3 = book(alice, 2, "공연 3");
        Ticket bobs = book(bob, 3, "밥의 공연");
        for (Ticket t : List.of(t1, t2, t3, bobs)) {
            t.markUsed();
        }
        em.flush();
        Long g1 = goodsService.create(alice.getId(), t1.getId(), command("c-1")).goods().goodsId();
        Long g2 = goodsService.create(alice.getId(), t2.getId(), command("c-2")).goods().goodsId();
        Long g3 = goodsService.create(alice.getId(), t3.getId(), command("c-3")).goods().goodsId();
        goodsService.create(bob.getId(), bobs.getId(), command("c-1"));

        Authenticated.set(alice.getId());
        mvc.perform(get(MY_GOODS_PATH).param("size", "2"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.content.length()").value(2))
                .andExpect(jsonPath("$.page.totalElements").value(3))
                .andExpect(jsonPath("$.content[*].goodsId", contains(g3.intValue(), g2.intValue())))
                .andExpect(jsonPath("$.content[0].ticketId").value(t3.getId().intValue()))
                .andExpect(jsonPath("$.content[0].clientGoodsId").value("c-3"))
                .andExpect(jsonPath("$.content[0].effectType").value("stageLights"))
                .andExpect(jsonPath("$.content[0].previewUrl").value("https://cdn.test.timo.io/preview.jpg"))
                .andExpect(jsonPath("$.content[0].concertSnapshot.title").value("공연 3"));

        mvc.perform(get(MY_GOODS_PATH).param("page", "1").param("size", "2"))
                .andExpect(jsonPath("$.content.length()").value(1))
                .andExpect(jsonPath("$.content[0].goodsId").value(g1.intValue()));

        mvc.perform(get(MY_GOODS_PATH).param("size", "101"))
                .andExpect(status().isBadRequest());
    }

    @Test
    @DisplayName("상세는 저장된 전 필드와 key 별 URL 을 함께 주고, 남의 것은 404 다")
    void goodsDetail() throws Exception {
        Ticket ticket = book(alice, 0, "아이유 콘서트");
        ticket.markUsed();
        em.flush();
        Long goodsId = goodsService.create(alice.getId(), ticket.getId(), command("c-1")).goods().goodsId();

        Authenticated.set(alice.getId());
        mvc.perform(get(GOODS_PATH, goodsId))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.goodsId").value(goodsId.intValue()))
                .andExpect(jsonPath("$.ticketId").value(ticket.getId().intValue()))
                .andExpect(jsonPath("$.clientGoodsId").value("c-1"))
                .andExpect(jsonPath("$.backgroundKey").value("bg.png"))
                .andExpect(jsonPath("$.backgroundUrl").value("https://cdn.test.timo.io/bg.png"))
                .andExpect(jsonPath("$.depthMapUrl").value("https://cdn.test.timo.io/depth.png"))
                .andExpect(jsonPath("$.sourceBackgroundKey").value((Object) null))
                .andExpect(jsonPath("$.sourceBackgroundUrl").value((Object) null))
                .andExpect(jsonPath("$.effectType").value("stageLights"))
                .andExpect(jsonPath("$.backgroundFraming").value((Object) null))
                .andExpect(jsonPath("$.personLayers.length()").value(2))
                .andExpect(jsonPath("$.personLayers[0].cutoutKey").value("cut-0.png"))
                .andExpect(jsonPath("$.personLayers[0].cutoutUrl").value("https://cdn.test.timo.io/cut-0.png"))
                .andExpect(jsonPath("$.personLayers[0].depthStrength").value("weak"))
                .andExpect(jsonPath("$.personLayers[0].parts[0].partMapUrl")
                        .value("https://cdn.test.timo.io/part-0.png"))
                .andExpect(jsonPath("$.transitionConfig.durationMs").value(610))
                .andExpect(jsonPath("$.renderMetadata.model").value("on-device"))
                .andExpect(jsonPath("$.concertSnapshot.title").value("아이유 콘서트"))
                .andExpect(jsonPath("$.createdAt").exists());

        Authenticated.set(bob.getId());
        mvc.perform(get(GOODS_PATH, goodsId))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.exception").value("GoodsNotFoundException"));
    }

    // ---------------------------------------------------------------- 헬퍼

    /** 실행 중 나간 JDBC 문장 수. 설정 파일 없이 런타임에 통계를 켠다. */
    private long countStatements(ThrowingAction action) throws Exception {
        Statistics statistics = em.getEntityManagerFactory().unwrap(SessionFactory.class).getStatistics();
        statistics.setStatisticsEnabled(true);
        statistics.clear();
        try {
            action.run();
            return statistics.getPrepareStatementCount();
        } finally {
            statistics.setStatisticsEnabled(false);
        }
    }

    @FunctionalInterface
    private interface ThrowingAction {
        void run() throws Exception;
    }

    private CreateGoodsCommand command(String clientGoodsId) {
        return command(clientGoodsId, mapper.readTree("""
                [{"cutoutKey":"cut-0.png","depthMapKey":"depth-0.png","depthStrength":"weak",
                  "left":0.1,"top":0.2,"width":0.5,"height":0.6,"layerOrder":0,
                  "parts":[{"partMapKey":"part-0.png","name":"head"}]},
                 {"cutoutKey":"cut-1.png","layerOrder":1,"parts":[]}]
                """));
    }

    private CreateGoodsCommand command(String clientGoodsId, JsonNode personLayers) {
        return new CreateGoodsCommand(
                clientGoodsId,
                "bg.png",
                null,
                "composite.png",
                "depth.png",
                "preview.jpg",
                GoodsEffect.stageLights,
                null,
                personLayers,
                mapper.readTree("{\"durationMs\":610}"),
                mapper.readTree("{\"model\":\"on-device\"}"));
    }

    /** 예매하고 발행까지 끝난 티켓. 공연을 새로 만드는 이유는 한 계정 한 공연 1매 때문이다. */
    private Ticket book(Member member, int seatIndex, String concertTitle) {
        Concert concert = saveConcert(concertTitle, 20 + seatIndex);
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert)
                .member(member)
                .seat(seats.get(seatIndex))
                .build());

        Ticket ticket = ticketRepository.save(Ticket.builder().reservation(reservation).build());
        ticket.markMinted(BigInteger.valueOf(ticket.getId() + 1_000L), "0x" + "1".repeat(64));
        return ticket;
    }

    /** 매물을 열고 바로 체결시킨다. 소유자 판정만 보면 되므로 서비스를 거치지 않는다. */
    private void trade(Ticket ticket, Member seller, Member buyer, LocalDateTime tradedAt) {
        ticketRepository.findById(ticket.getId()).orElseThrow().markListed();
        TicketListing listing = ticketListingRepository.saveAndFlush(TicketListing.open(
                ticket.getId(),
                seller.getId(),
                ticket.getReservation().getConcert(),
                section,
                ticket.getReservation().getSeat().getSeatNo(),
                ticket.getReservation().getSeat().getSeatCol(),
                SEAT_PRICE - 10_000L,
                SEAT_PRICE,
                LocalDateTime.now()));
        em.flush();
        ticketListingRepository.markSoldIfListed(listing.getId(), tradedAt);
        TicketListing sold = ticketListingRepository.findById(listing.getId()).orElseThrow();
        TicketTrade trade = TicketTrade.record(sold, buyer.getId(), tradedAt);
        trade.confirm();
        ticketTradeRepository.save(trade);
        org.assertj.core.api.Assertions.assertThat(ticketRepository.transferOwnershipIfListed(
                ticket.getId(), seller.getId(), buyer.getId(), tradedAt)).isEqualTo(1);
    }

    /**
     * 양도 뒤에 입장 처리한다. 체결 헬퍼의 {@code markSoldIfListed} 가 영속성 컨텍스트를 비워
     * ({@code clearAutomatically}) 들고 있던 티켓이 떨어져 나가므로, 다시 읽어서 바꿔야 flush 된다.
     */
    private void markUsedAfterTrade(Ticket ticket) {
        ticketRepository.findById(ticket.getId()).orElseThrow().markUsed();
        em.flush();
    }

    private Concert saveConcert(String title, int daysLater) {
        Concert concert = Concert.builder()
                .title(title)
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .posterImageKey("poster.jpg")
                .startDate(LocalDateTime.now().plusDays(daysLater))
                .endDate(LocalDateTime.now().plusDays(daysLater).plusHours(3))
                .openAt(LocalDateTime.now().plusDays(1))
                .venue(venue)
                .build();
        concert.addArtist(artist);
        return concertRepository.save(concert);
    }

    private Member saveMember(String phoneNumber, String nickname) {
        return memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber)
                .name("전재민")
                .nickname(nickname)
                .build());
    }

    private Section saveSection(Venue forVenue) {
        List<SeatPosition> positions = IntStream.rangeClosed(1, 3)
                .boxed()
                .flatMap(row -> IntStream.rangeClosed(1, 2)
                        .mapToObj(col -> new SeatPosition(row, col)))
                .toList();

        Section saved = sectionRepository.save(Section.builder()
                .name("1층 A블록")
                .price(SEAT_PRICE)
                .rowCount(3)
                .seatPerRow(2)
                .venue(forVenue)
                .build());

        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }
}
