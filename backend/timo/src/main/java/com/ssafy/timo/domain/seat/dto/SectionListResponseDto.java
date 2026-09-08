package com.ssafy.timo.domain.seat.dto;

import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.venue.entity.Venue;

import java.util.List;
import java.util.Map;

/**
 * 공연장의 구역 목록 응답. 좌석을 고르기 전 단계인 구역 선택 화면이 쓴다.
 *
 * <p>개별 좌석은 담지 않는다. 공연장 전체 좌석은 수만 건이 될 수 있어 한 응답에 실을 크기가 아니다.
 * 구역을 고른 다음 {@link SectionSeatListResponseDto} 로 그 구역의 좌석만 받아 간다.
 *
 * <p>페이지로 나누지 않는다. 구역은 공연장 하나에 많아야 수십 개고, 구역 선택 화면은 전체를
 * 한 번에 그려야 한다.
 */
public record SectionListResponseDto(
        Long venueId,
        String venueName,
        int totalSeatCount,
        int totalAvailableCount,
        List<SectionSummary> sections
) {

    /**
     * @param availableCounts 구역 id 별 예매 가능 좌석 수. 남은 좌석이 없는 구역은 키가 없을 수 있다.
     */
    public static SectionListResponseDto from(Venue venue,
                                              List<Section> sections,
                                              Map<Long, Long> availableCounts) {
        List<SectionSummary> summaries = sections.stream()
                .map(section -> SectionSummary.from(
                        section, availableCounts.getOrDefault(section.getId(), 0L)))
                .toList();

        return new SectionListResponseDto(
                venue.getId(),
                venue.getName(),
                summaries.stream().mapToInt(SectionSummary::seatCount).sum(),
                summaries.stream().mapToInt(SectionSummary::availableCount).sum(),
                summaries);
    }

    /**
     * 구역 하나의 요약.
     *
     * <p>{@code seatCount} 는 등록된 좌석 수, {@code availableCount} 는 그중 아직 예매 가능한 수다.
     * {@code rowCount} · {@code seatPerRow} 는 배치도 격자 크기일 뿐 좌석 수와 일치하지 않는다.
     * 스탠딩처럼 격자로 표현되지 않는 구역은 둘 다 {@code null} 이다.
     */
    public record SectionSummary(
            Long id,
            String name,
            SeatGrade grade,
            int price,
            int seatCount,
            int availableCount,
            Integer rowCount,
            Integer seatPerRow
    ) {

        static SectionSummary from(Section section, long availableCount) {
            return new SectionSummary(
                    section.getId(),
                    section.getName(),
                    section.getGrade(),
                    section.getPrice(),
                    section.getSeatCount(),
                    Math.toIntExact(availableCount),
                    section.getRowCount(),
                    section.getSeatPerRow());
        }
    }
}
