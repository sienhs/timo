package com.ssafy.timo.global.init;

import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto;
import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto.SeatPositionRequest;
import com.ssafy.timo.domain.seat.dto.CommandSeatRequestDto.SectionLayout;
import com.ssafy.timo.domain.seat.dto.CommandSeatResponseDto;
import com.ssafy.timo.domain.seat.repository.SectionRepository;
import com.ssafy.timo.domain.seat.service.SeatService;
import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import com.ssafy.timo.domain.venue.service.VenueService;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * 공연장·구역·좌석 카탈로그. {@code LocalDataSeeder}(local·demo)와 {@code ProdCatalogSeeder}(prod)가
 * 공통으로 필요로 해서 뽑았다 - 둘 다 같은 사다리꼴 배치의 "고척돔"을 쓰고, 이 부분만 두 곳에
 * 복사해 두면 나중에 하나만 고치고 하나는 놓치는 위험이 생긴다.
 *
 * <p>공연 자체(무엇을 파는가)나 온체인 등록은 여기서 다루지 않는다 - 그건 호출하는 쪽마다 성격이
 * 달라서(로컬은 5건짜리 더미, 운영은 크롤링된 48건) 공유할 이유가 없다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class VenueSeatCatalogSeeder {

    /** 공연장명은 10자 제한이다. */
    private static final String VENUE_NAME = "고척돔";
    private static final String VENUE_ADDRESS = "서울시 구로구 경인로 430";

    /**
     * 시드 배치도의 행 수. 구역마다 같다 - 행마다 좌석 수가 다른 사다리꼴 배치라 그 폭은
     * {@link SectionSeed#rowSeatCounts} 가 따로 정한다.
     */
    private static final int ROW_COUNT = 10;

    /** 구역 하나의 좌석 수. 행마다 폭이 달라도 구역 전체 합은 어느 구역이나 같다(A~E 전부 200석). */
    private static final int SEATS_PER_SECTION = 200;

    /**
     * 무대에 가까운 1층 구역(A·B). 앞줄일수록 좁고 뒤로 갈수록 넓어지는 사다리꼴이다 - 5열과 6열
     * 사이(가로 통로)에서만 한 번에 두 석씩 넓어진다.
     */
    private static final List<Integer> ROW_SEAT_COUNTS_FRONT = List.of(15, 16, 17, 18, 19, 21, 22, 23, 24, 25);

    /** 1층 뒤쪽 구역(C). 무대에서 멀어 폭이 완만하게만 넓어진다. */
    private static final List<Integer> ROW_SEAT_COUNTS_REAR = List.of(18, 19, 19, 20, 20, 20, 20, 21, 21, 22);

    /** 2층 구역(D·E). 1층과 반대로 앞(무대 쪽)이 넓고 뒤로 갈수록 좁아진다. */
    private static final List<Integer> ROW_SEAT_COUNTS_UPPER = List.of(25, 24, 23, 22, 21, 19, 18, 17, 16, 15);

    /**
     * 구역 하나의 시드 정보. 등급은 아직 구분이 없어 서버가 {@code COMMON} 으로 정한다.
     *
     * @param rowSeatCounts 1열부터 10열까지, 열마다 좌석이 몇 석인지(사다리꼴 배치). 합은 항상
     *                      {@link #SEATS_PER_SECTION}이어야 한다.
     */
    private record SectionSeed(String name, int price, List<Integer> rowSeatCounts) {

        /** 배치도 격자 폭 - 가장 넓은 열의 좌석 수. 구역마다 다르다(25 또는 22). */
        int seatPerRow() {
            return Collections.max(rowSeatCounts);
        }
    }

    /** 시드 구역 5개. 층이 올라갈수록 가격을 낮춰 구역 선택 화면에서 가격대가 갈리는 것을 볼 수 있게 했다. */
    private static final List<SectionSeed> SECTION_SEEDS = List.of(
            new SectionSeed("A구역", 150_000, ROW_SEAT_COUNTS_FRONT),
            new SectionSeed("B구역", 150_000, ROW_SEAT_COUNTS_FRONT),
            new SectionSeed("C구역", 120_000, ROW_SEAT_COUNTS_REAR),
            new SectionSeed("2층 D구역", 120_000, ROW_SEAT_COUNTS_UPPER),
            new SectionSeed("2층 E구역", 99_000, ROW_SEAT_COUNTS_UPPER));

    private final VenueRepository venueRepository;
    private final VenueService venueService;
    private final SectionRepository sectionRepository;
    private final SeatService seatService;

    /** 이 카탈로그의 전체 좌석 수(구역 5개 x 200석). {@code registerShow}의 totalSeats에 쓴다. */
    public static int totalSeatCount() {
        return SECTION_SEEDS.size() * SEATS_PER_SECTION;
    }

    /** 공연장을 찾거나 등록하고, 구역·좌석까지 채운 뒤 공연장 id를 돌려준다. */
    public Long seedVenueAndSeats() {
        Long venueId = findOrRegisterVenue();
        seedSeats(venueId);
        return venueId;
    }

    /**
     * 고정 공연장이 이미 있으면 그것을 쓴다. 등록 API 는 이름 중복을 409 로 막으므로 먼저 확인한다.
     *
     * <p>운영에서는 {@code seed-venue.sql}이 이 이름으로 미리 넣어 둔 행을 여기서 찾아 쓴다 -
     * {@code seed-concerts.sql}의 {@code concert.venue_id=1}이 그 행을 가리키므로, 이 시더가
     * 새로 만들면 안 된다.
     */
    private Long findOrRegisterVenue() {
        return venueRepository.findByName(VENUE_NAME)
                .map(Venue::getId)
                .orElseGet(() -> venueService.register(new CommandVenueRequestDto(
                        VENUE_NAME,
                        VENUE_ADDRESS,
                        totalSeatCount())).id());
    }

    /**
     * 공연장의 구역과 좌석을 한 번에 등록한다.
     *
     * <p>구역이 이미 있으면 넘어간다. 구역명은 공연장 안에서 유일해서, 남아 있는 배치도 위에 다시 등록하면
     * 기동이 409 로 실패한다.
     */
    private void seedSeats(Long venueId) {
        // 구역 조회 API 는 이제 공연 기준이라 여기 쓸 수 없다. "이 공연장에 구역이 있는가" 는
        // 공연과 무관한 질문이므로 리포지토리에 직접 묻는다.
        if (!sectionRepository.findAllByVenueIdOrderByIdAsc(venueId).isEmpty()) {
            log.info("공연장 {} 에 구역이 이미 있어 좌석 시드를 건너뛴다.", venueId);
            return;
        }

        CommandSeatResponseDto registered = seatService.register(new CommandSeatRequestDto(
                venueId,
                SECTION_SEEDS.stream()
                        .map(seed -> new SectionLayout(
                                seed.name(), seed.price(), ROW_COUNT, seed.seatPerRow(), trapezoidPositions(seed.rowSeatCounts())))
                        .toList()));

        log.info("공연장 카탈로그: 구역 {}개 · 좌석 {}석을 넣었다.",
                registered.sections().size(), registered.totalSeatCount());
    }

    /**
     * 행마다 폭이 다른 사다리꼴 자리 목록. 행 우선으로 나열해 배치도 순서와 같다.
     *
     * <p>자리 번호(seatCol)는 실제 격자 폭({@link SectionSeed#seatPerRow}) 과 무관하게 매 행 1번부터
     * 시작한다 - 화면 가운데 정렬은 프론트가 한다({@code CommandSeatRequestDto} 주석 참고).
     */
    private List<SeatPositionRequest> trapezoidPositions(List<Integer> rowSeatCounts) {
        List<SeatPositionRequest> positions = new ArrayList<>(SEATS_PER_SECTION);
        for (int seatNo = 1; seatNo <= rowSeatCounts.size(); seatNo++) {
            int rowWidth = rowSeatCounts.get(seatNo - 1);
            for (int seatCol = 1; seatCol <= rowWidth; seatCol++) {
                positions.add(new SeatPositionRequest(seatNo, seatCol));
            }
        }
        return positions;
    }
}
