package com.ssafy.timo.domain.concert;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertImagePurpose;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
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
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.support.Authenticated;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import java.math.BigInteger;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.IntStream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

/**
 * 공연 소재(kit) 통합 테스트.
 *
 * <p>여기서만 볼 수 있는 것이 둘이다. 소재를 볼 자격을 가리는 쿼리가 네이티브라 DB 없이는 문법조차
 * 검증되지 않고, <b>소재가 공연 상세에 섞이지 않는지</b>는 같은 표를 쓰는 구조라 실제로 읽어 봐야 한다.
 *
 * <p>인가 규칙(등록은 ADMIN·ORGANIZER 만)은 여기서 검증되지 않는다 - {@link IntegrationTest} 가
 * 시큐리티 필터를 태우지 않기 때문이다. 그 규칙은 {@code SecurityConfig} 가 가진다.
 */
@IntegrationTest
class ConcertKitApiIntegrationTest {

    private static final String KIT_PATH = "/api/v1/concerts/{concertId}/kit";
    private static final String KIT_IMAGES_PATH = "/api/v1/concerts/{concertId}/kit/images";
    private static final String CONCERT_PATH = "/api/v1/concerts/{concertId}";
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
    private MemberRepository memberRepository;

    @Autowired
    private ReservationRepository reservationRepository;

    @Autowired
    private TicketRepository ticketRepository;

    @Autowired
    private EntityManager em;

    private Member holder;
    private Member stranger;
    private Concert concert;
    private List<Seat> seats;

    @BeforeEach
    void setUpFixtures() {
        Venue venue = venueRepository.save(Venue.builder()
                .name("고척돔").address("서울시 구로구").totalSeatCount(16000).build());
        Section section = saveSection(venue);
        seats = seatRepository.findAllBySectionIdOrderBySeatNoAscSeatColAsc(section.getId());
        concert = concertRepository.save(Concert.builder()
                .title("아이유 콘서트")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .posterImageKey("poster.jpg")
                .startDate(LocalDateTime.now().plusDays(20))
                .endDate(LocalDateTime.now().plusDays(20).plusHours(3))
                .openAt(LocalDateTime.now().plusDays(1))
                .venue(venue)
                .build());

        holder = saveMember("01011112222", "앨리스");
        stranger = saveMember("01033334444", "밥");
        book(holder, 0);
        em.flush();
    }

    @AfterEach
    void clearRequester() {
        Authenticated.clear();
    }

    @Test
    @DisplayName("티켓을 가진 사람에게는 배경과 인물이 순서대로 나간다")
    void returnsKitToHolder() throws Exception {
        concert.addKitImage("concert/kit/bg1.png", ConcertImagePurpose.KIT_BACKGROUND);
        concert.addKitImage("concert/kit/bg2.png", ConcertImagePurpose.KIT_BACKGROUND);
        concert.addKitImage("concert/kit/p1.png", ConcertImagePurpose.KIT_PERSON);
        em.flush();

        mvc.perform(get(KIT_PATH, concert.getId()).with(Authenticated.as(holder.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.concertId").value(concert.getId()))
                .andExpect(jsonPath("$.backgrounds.length()").value(2))
                .andExpect(jsonPath("$.backgrounds[0].sortOrder").value(0))
                .andExpect(jsonPath("$.backgrounds[1].sortOrder").value(1))
                .andExpect(jsonPath("$.people.length()").value(1))
                // 서버가 축소본을 만들지 않으므로 썸네일은 원본과 같은 URL 이다.
                .andExpect(jsonPath("$.people[0].thumbnailUrl").value("https://cdn.test.timo.io/concert/kit/p1.png"));
    }

    @Test
    @DisplayName("소재가 없는 공연도 정상 - 빈 배열이 나간다")
    void returnsEmptyKit() throws Exception {
        mvc.perform(get(KIT_PATH, concert.getId()).with(Authenticated.as(holder.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.backgrounds.length()").value(0))
                .andExpect(jsonPath("$.people.length()").value(0));
    }

    @Test
    @DisplayName("그 공연 티켓이 없으면 403 - 공연은 공개라 존재를 숨기지 않는다")
    void rejectsNonHolder() throws Exception {
        mvc.perform(get(KIT_PATH, concert.getId()).with(Authenticated.as(stranger.getId())))
                .andExpect(status().isForbidden())
                .andExpect(jsonPath("$.exception").value("ConcertKitForbiddenException"));
    }

    @Test
    @DisplayName("없는 공연은 404")
    void rejectsMissingConcert() throws Exception {
        mvc.perform(get(KIT_PATH, 999_999L).with(Authenticated.as(holder.getId())))
                .andExpect(status().isNotFound());
    }

    @Test
    @DisplayName("등록하면 바로 조회에 반영되고, 같은 용도끼리 순서가 이어진다")
    void addsKitImages() throws Exception {
        mvc.perform(multipart(KIT_IMAGES_PATH, concert.getId())
                        .file(png("bg1.png"))
                        .file(png("bg2.png"))
                        .param("purpose", "KIT_BACKGROUND")
                        .with(Authenticated.as(holder.getId())))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.backgrounds.length()").value(2))
                // 등록 화면이 방금 올린 소재를 가리키려면 id 가 있어야 한다.
                .andExpect(jsonPath("$.backgrounds[0].assetId").isNumber());

        mvc.perform(multipart(KIT_IMAGES_PATH, concert.getId())
                        .file(png("p1.png"))
                        .param("purpose", "KIT_PERSON")
                        .with(Authenticated.as(holder.getId())))
                .andExpect(status().isCreated());

        em.flush();
        em.clear();
        mvc.perform(get(KIT_PATH, concert.getId()).with(Authenticated.as(holder.getId())))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.backgrounds.length()").value(2))
                .andExpect(jsonPath("$.backgrounds[1].sortOrder").value(1))
                // 인물은 배경과 따로 센다.
                .andExpect(jsonPath("$.people[0].sortOrder").value(0));
    }

    @Test
    @DisplayName("소재는 공연 상세에 섞이지 않는다 - 상세는 인증 없이 열리는 공개 API 다")
    void kitNeverLeaksIntoConcertDetail() throws Exception {
        concert.addImage("concert/detail1.png");
        concert.addKitImage("concert/kit/bg1.png", ConcertImagePurpose.KIT_BACKGROUND);
        em.flush();
        em.clear();

        mvc.perform(get(CONCERT_PATH, concert.getId()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.imageUrls.length()").value(1))
                .andExpect(jsonPath("$.imageUrls[0]").value("https://cdn.test.timo.io/concert/detail1.png"));
    }

    @Test
    @DisplayName("소재를 더해도 상세 이미지의 순서가 밀리지 않는다")
    void detailOrderUnaffected() {
        concert.addImage("concert/detail1.png");
        concert.addKitImage("concert/kit/bg1.png", ConcertImagePurpose.KIT_BACKGROUND);
        concert.addImage("concert/detail2.png");
        em.flush();
        em.clear();

        Concert reloaded = concertRepository.findById(concert.getId()).orElseThrow();
        assertThat(reloaded.getImages())
                .extracting(image -> image.getSortOrder())
                .containsExactly(0, 1);
        assertThat(reloaded.getKitImages(ConcertImagePurpose.KIT_BACKGROUND)).hasSize(1);
    }

    private MockMultipartFile png(String name) {
        return new MockMultipartFile("files", name, "image/png", new byte[]{1, 2, 3});
    }

    private Section saveSection(Venue forVenue) {
        List<SeatPosition> positions = IntStream.rangeClosed(1, 3)
                .boxed()
                .flatMap(row -> IntStream.rangeClosed(1, 2).mapToObj(col -> new SeatPosition(row, col)))
                .toList();
        Section saved = sectionRepository.save(Section.builder()
                .name("1층 A블록").price(SEAT_PRICE).rowCount(3).seatPerRow(2).venue(forVenue).build());
        seatRepository.saveAll(saved.createSeats(positions));
        return saved;
    }

    private Member saveMember(String phoneNumber, String nickname) {
        return memberRepository.save(Member.builder()
                .phoneNumber(phoneNumber).name("전재민").nickname(nickname).build());
    }

    private Ticket book(Member member, int seatIndex) {
        Reservation reservation = reservationRepository.save(Reservation.builder()
                .concert(concert).member(member).seat(seats.get(seatIndex)).build());
        Ticket ticket = ticketRepository.save(Ticket.builder().reservation(reservation).build());
        ticket.markMinted(BigInteger.valueOf(ticket.getId() + 1_000L), "0x" + "1".repeat(64));
        return ticket;
    }
}
