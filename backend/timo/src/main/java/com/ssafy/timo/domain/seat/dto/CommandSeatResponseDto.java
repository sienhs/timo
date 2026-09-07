package com.ssafy.timo.domain.seat.dto;

import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.seat.entity.Section;
import com.ssafy.timo.domain.venue.entity.Venue;

import java.util.List;

/**
 * 좌석 등록 응답. 등록된 구역들과 각 구역에 만들어진 좌석 수를 돌려준다.
 *
 * <p>좌석 개별 목록은 싣지 않는다. 구역 하나에 수천 건이 될 수 있어 등록 응답으로 내리기에 너무 크고,
 * 좌석 목록은 좌석 배치도 조회에서 따로 받아 가면 된다.
 *
 * <p>잔여석도 싣지 않는다. 갓 등록된 좌석은 전부 예매 가능이므로 {@code seatCount} 와 같다.
 */
public record CommandSeatResponseDto(
        Long venueId,
        String venueName,
        int totalSeatCount,
        List<SectionSummary> sections
) {

    public static CommandSeatResponseDto from(Venue venue, List<Section> sections) {
        List<SectionSummary> summaries = sections.stream()
                .map(SectionSummary::from)
                .toList();

        return new CommandSeatResponseDto(
                venue.getId(),
                venue.getName(),
                summaries.stream().mapToInt(SectionSummary::seatCount).sum(),
                summaries);
    }

    /** 등록된 구역 요약. */
    public record SectionSummary(
            Long id,
            String name,
            SeatGrade grade,
            int price,
            int seatCount,
            Integer rowCount,
            Integer seatPerRow
    ) {

        static SectionSummary from(Section section) {
            return new SectionSummary(
                    section.getId(),
                    section.getName(),
                    section.getGrade(),
                    section.getPrice(),
                    section.getSeatCount(),
                    section.getRowCount(),
                    section.getSeatPerRow());
        }
    }
}
