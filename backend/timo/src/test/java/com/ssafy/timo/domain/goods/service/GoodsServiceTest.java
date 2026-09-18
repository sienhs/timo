package com.ssafy.timo.domain.goods.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.goods.dto.CreateGoodsCommand;
import com.ssafy.timo.domain.goods.dto.GoodsCreateResult;
import com.ssafy.timo.domain.goods.entity.Goods;
import com.ssafy.timo.domain.goods.entity.GoodsEffect;
import com.ssafy.timo.domain.goods.exception.GoodsAlreadyExistsException;
import com.ssafy.timo.domain.goods.exception.GoodsInvalidLayersException;
import com.ssafy.timo.domain.goods.exception.GoodsTicketNotOwnedException;
import com.ssafy.timo.domain.goods.exception.GoodsTicketNotUsedException;
import com.ssafy.timo.domain.goods.repository.GoodsRepository;
import com.ssafy.timo.domain.member.entity.Member;
import org.springframework.test.util.ReflectionTestUtils;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.global.storage.PlaceholderImageStorage;
import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * 굿즈 생성 규칙을 검증한다.
 *
 * <p>{@link TransactionTemplate} 은 목이 아니라 <b>목 트랜잭션 매니저를 끼운 실제 템플릿</b>이다.
 * 콜백이 실제로 돌고 예외가 밖으로 나가야 "유니크 위반 → 재판정" 흐름을 볼 수 있다.
 * {@link GoodsJson}·{@link GoodsMapper} 도 실제 구현이다 — 스냅샷이 제대로 만들어지는지까지 본다.
 */
@ExtendWith(MockitoExtension.class)
class GoodsServiceTest {

    private static final long MEMBER_ID = 7L;
    private static final long OTHER_MEMBER_ID = 8L;
    private static final long TICKET_ID = 42L;

    @Mock
    private GoodsRepository goodsRepository;

    @Mock
    private TicketRepository ticketRepository;

    @Mock
    private MemberRepository memberRepository;

    private final JsonMapper mapper = JsonMapper.builder().build();

    private GoodsService service;
    private Concert concert;

    @BeforeEach
    void setUp() {
        GoodsJson goodsJson = new GoodsJson(mapper);
        GoodsMapper goodsMapper = new GoodsMapper(new PlaceholderImageStorage("https://cdn.example"), goodsJson);
        TransactionTemplate transactionTemplate = new TransactionTemplate(mock(PlatformTransactionManager.class));
        service = new GoodsService(goodsRepository, ticketRepository, memberRepository,
                goodsJson, goodsMapper, transactionTemplate);

        concert = Concert.builder()
                .title("아이유 콘서트")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .posterImageKey("poster.jpg")
                .startDate(LocalDateTime.of(2026, 9, 26, 19, 0))
                .venue(Venue.builder().name("고척돔").address("서울").totalSeatCount(100).build())
                .build();
        concert.addArtist(Artist.builder().name("아이유").build());
        concert.addArtist(Artist.builder().name("게스트").build());
    }

    @Test
    @DisplayName("입장 완료한 내 티켓이면 만들고, 공연 스냅샷을 서버가 채운다")
    void createsWithSnapshot() {
        Ticket ticket = usedTicket();
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(1L);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ticket));
        given(goodsRepository.findByTicketId(TICKET_ID)).willReturn(Optional.empty());
        given(goodsRepository.findByMemberIdAndClientGoodsId(MEMBER_ID, "c-1")).willReturn(Optional.empty());
        given(memberRepository.getReferenceById(MEMBER_ID)).willReturn(member());
        given(goodsRepository.saveAndFlush(any(Goods.class))).willAnswer(inv -> inv.getArgument(0));

        GoodsCreateResult result = service.create(MEMBER_ID, TICKET_ID, command("c-1", validLayers()));

        assertThat(result.created()).isTrue();
        ArgumentCaptor<Goods> captor = ArgumentCaptor.forClass(Goods.class);
        verify(goodsRepository).saveAndFlush(captor.capture());
        Goods saved = captor.getValue();
        assertThat(saved.getConcert()).isSameAs(concert);
        assertThat(saved.getEffectType()).isEqualTo(GoodsEffect.stageLights);
        assertThat(saved.getBackgroundFraming()).isNull();

        JsonNode snapshot = mapper.readTree(saved.getConcertSnapshot());
        assertThat(snapshot.get("title").stringValue()).isEqualTo("아이유 콘서트");
        assertThat(snapshot.get("artist").stringValue()).isEqualTo("아이유, 게스트");
        assertThat(snapshot.get("date").stringValue()).isEqualTo("2026-09-26T19:00:00");
        assertThat(snapshot.get("venue").stringValue()).isEqualTo("고척돔");

        // 응답에는 key 와 URL 이 함께 있고, 레이어 안의 key 도 URL 이 붙는다.
        assertThat(result.goods().backgroundUrl()).isEqualTo("https://cdn.example/bg.png");
        assertThat(result.goods().personLayers().get(0).get("cutoutUrl").stringValue())
                .isEqualTo("https://cdn.example/cut-0.png");
        assertThat(result.goods().concertSnapshot().get("artist").stringValue()).isEqualTo("아이유, 게스트");
    }

    @Test
    @DisplayName("레이어가 3개면 DB 를 만지기 전에 400")
    void threeLayersRejectedBeforeDb() {
        JsonNode layers = mapper.readTree("[{\"layerOrder\":0},{\"layerOrder\":1},{\"layerOrder\":2}]");

        assertThatThrownBy(() -> service.create(MEMBER_ID, TICKET_ID, command("c-1", layers)))
                .isInstanceOf(GoodsInvalidLayersException.class);

        verify(goodsRepository, never()).countCurrentOwnership(any(), any());
    }

    @Test
    @DisplayName("layerOrder 가 겹치면 400")
    void duplicateLayerOrder() {
        JsonNode layers = mapper.readTree("[{\"layerOrder\":0},{\"layerOrder\":0}]");

        assertThatThrownBy(() -> service.create(MEMBER_ID, TICKET_ID, command("c-1", layers)))
                .isInstanceOf(GoodsInvalidLayersException.class);
    }

    @Test
    @DisplayName("지금 내 티켓이 아니면 404 - 존재 여부를 알리지 않는다")
    void notOwned() {
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(0L);

        assertThatThrownBy(() -> service.create(MEMBER_ID, TICKET_ID, command("c-1", validLayers())))
                .isInstanceOf(GoodsTicketNotOwnedException.class);

        verify(ticketRepository, never()).findById(any());
    }

    @Test
    @DisplayName("입장 전(OWNED) 티켓이면 409")
    void notUsed() {
        Ticket ticket = Ticket.builder().reservation(reservation()).build();
        ticket.markMinted(BigInteger.ONE, "0x" + "1".repeat(64));
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(1L);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(ticket));

        assertThatThrownBy(() -> service.create(MEMBER_ID, TICKET_ID, command("c-1", validLayers())))
                .isInstanceOf(GoodsTicketNotUsedException.class);

        verify(goodsRepository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("같은 clientGoodsId 재전송이면 저장하지 않고 기존 굿즈를 돌려준다")
    void idempotentRetry() {
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(1L);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(usedTicket()));
        given(goodsRepository.findByTicketId(TICKET_ID)).willReturn(Optional.of(existingGoods("c-1")));

        GoodsCreateResult result = service.create(MEMBER_ID, TICKET_ID, command("c-1", validLayers()));

        assertThat(result.created()).isFalse();
        assertThat(result.goods().clientGoodsId()).isEqualTo("c-1");
        verify(goodsRepository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("이 티켓의 굿즈가 남의 것이면 멱등 키가 같아도 409 - 남의 굿즈를 돌려주지 않는다")
    void otherOwnersGoodsConflicts() {
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(1L);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(usedTicket()));
        given(goodsRepository.findByTicketId(TICKET_ID))
                .willReturn(Optional.of(existingGoods("c-1", OTHER_MEMBER_ID)));

        assertThatThrownBy(() -> service.create(MEMBER_ID, TICKET_ID, command("c-1", validLayers())))
                .isInstanceOf(GoodsAlreadyExistsException.class);
    }

    @Test
    @DisplayName("이미 있는데 다른 clientGoodsId 면 409")
    void differentClientIdConflicts() {
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(1L);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(usedTicket()));
        given(goodsRepository.findByTicketId(TICKET_ID)).willReturn(Optional.of(existingGoods("c-1")));

        assertThatThrownBy(() -> service.create(MEMBER_ID, TICKET_ID, command("c-2", validLayers())))
                .isInstanceOf(GoodsAlreadyExistsException.class);
    }

    @Test
    @DisplayName("같은 clientGoodsId 를 다른 티켓에 이미 썼으면 409 - 유니크 위반으로 500 이 나기 전에 거른다")
    void clientIdReusedOnAnotherTicket() {
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(1L);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(usedTicket()));
        given(goodsRepository.findByTicketId(TICKET_ID)).willReturn(Optional.empty());
        given(goodsRepository.findByMemberIdAndClientGoodsId(MEMBER_ID, "c-1"))
                .willReturn(Optional.of(existingGoods("c-1")));

        assertThatThrownBy(() -> service.create(MEMBER_ID, TICKET_ID, command("c-1", validLayers())))
                .isInstanceOf(GoodsAlreadyExistsException.class);

        verify(goodsRepository, never()).saveAndFlush(any());
    }

    @Test
    @DisplayName("동시 요청이 유니크 제약에서 지면, 다시 읽어 같은 키면 기존 굿즈를 200 으로 돌려준다")
    void uniqueViolationResolvedAsRetry() {
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(1L);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(usedTicket()));
        // 첫 조회 땐 없었고(둘 다 통과), 위반 뒤 다시 읽으면 이긴 쪽이 만든 것이 있다.
        given(goodsRepository.findByTicketId(TICKET_ID))
                .willReturn(Optional.empty(), Optional.of(existingGoods("c-1")));
        given(goodsRepository.findByMemberIdAndClientGoodsId(MEMBER_ID, "c-1")).willReturn(Optional.empty());
        given(memberRepository.getReferenceById(MEMBER_ID)).willReturn(member());
        given(goodsRepository.saveAndFlush(any(Goods.class)))
                .willThrow(new DataIntegrityViolationException("uk_goods_ticket"));

        GoodsCreateResult result = service.create(MEMBER_ID, TICKET_ID, command("c-1", validLayers()));

        assertThat(result.created()).isFalse();
        assertThat(result.goods().clientGoodsId()).isEqualTo("c-1");
    }

    @Test
    @DisplayName("유니크 제약에서 졌는데 이긴 쪽의 키가 다르면 409")
    void uniqueViolationResolvedAsConflict() {
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(1L);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(usedTicket()));
        given(goodsRepository.findByTicketId(TICKET_ID))
                .willReturn(Optional.empty(), Optional.of(existingGoods("c-other")));
        given(goodsRepository.findByMemberIdAndClientGoodsId(MEMBER_ID, "c-1")).willReturn(Optional.empty());
        given(memberRepository.getReferenceById(MEMBER_ID)).willReturn(member());
        given(goodsRepository.saveAndFlush(any(Goods.class)))
                .willThrow(new DataIntegrityViolationException("uk_goods_ticket"));

        assertThatThrownBy(() -> service.create(MEMBER_ID, TICKET_ID, command("c-1", validLayers())))
                .isInstanceOf(GoodsAlreadyExistsException.class);
    }

    @Test
    @DisplayName("유니크 위반이 굿즈로 설명되지 않으면 원래 예외를 그대로 던진다")
    void unexplainedViolationRethrown() {
        given(goodsRepository.countCurrentOwnership(MEMBER_ID, TICKET_ID)).willReturn(1L);
        given(ticketRepository.findById(TICKET_ID)).willReturn(Optional.of(usedTicket()));
        given(goodsRepository.findByTicketId(TICKET_ID)).willReturn(Optional.empty());
        given(goodsRepository.findByMemberIdAndClientGoodsId(MEMBER_ID, "c-1")).willReturn(Optional.empty());
        given(memberRepository.getReferenceById(MEMBER_ID)).willReturn(member());
        given(goodsRepository.saveAndFlush(any(Goods.class)))
                .willThrow(new DataIntegrityViolationException("fk_something"));

        assertThatThrownBy(() -> service.create(MEMBER_ID, TICKET_ID, command("c-1", validLayers())))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    // ---------------------------------------------------------------- 픽스처

    private Ticket usedTicket() {
        Ticket ticket = Ticket.builder().reservation(reservation()).build();
        ticket.markMinted(BigInteger.ONE, "0x" + "1".repeat(64));
        ticket.markUsed();
        return ticket;
    }

    private Reservation reservation() {
        return Reservation.builder().concert(concert).member(member()).seat(null).build();
    }

    private Member member() {
        return Member.builder().phoneNumber("01011112222").name("전재민").nickname("앨리스").build();
    }

    private Goods existingGoods(String clientGoodsId) {
        return existingGoods(clientGoodsId, MEMBER_ID);
    }

    /** {@code ownerId} 를 다르게 주면 "남이 만든 굿즈" 가 된다. */
    private Goods existingGoods(String clientGoodsId, long ownerId) {
        Member owner = member();
        // 굿즈 조회가 소유자를 보므로 id 가 있어야 한다. 빌더로는 못 넣는 생성 값이다.
        ReflectionTestUtils.setField(owner, "id", ownerId);
        return Goods.builder()
                .ticket(usedTicket())
                .member(owner)
                .concert(concert)
                .clientGoodsId(clientGoodsId)
                .backgroundKey("bg.png")
                .effectType(GoodsEffect.laser)
                .personLayers("[]")
                .transitionConfig("{}")
                .renderMetadata("{}")
                .concertSnapshot("{\"title\":\"아이유 콘서트\"}")
                .build();
    }

    private JsonNode validLayers() {
        return mapper.readTree("""
                [{"cutoutKey":"cut-0.png","depthMapKey":"depth-0.png","depthStrength":"weak",
                  "left":0.1,"top":0.2,"width":0.5,"height":0.6,"layerOrder":0,
                  "parts":[{"partMapKey":"part-0.png","name":"head"}]},
                 {"cutoutKey":"cut-1.png","layerOrder":1,"parts":[]}]
                """);
    }

    private CreateGoodsCommand command(String clientGoodsId, JsonNode personLayers) {
        return new CreateGoodsCommand(
                clientGoodsId,
                "bg.png",
                "src-bg.png",
                "composite.png",
                "depth.png",
                "preview.jpg",
                GoodsEffect.stageLights,
                null,
                personLayers,
                mapper.readTree("{\"durationMs\":610}"),
                mapper.readTree("{\"model\":\"on-device\"}"));
    }
}
