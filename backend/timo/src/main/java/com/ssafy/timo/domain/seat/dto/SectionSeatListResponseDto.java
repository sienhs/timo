package com.ssafy.timo.domain.seat.dto;

import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.domain.seat.entity.SeatGrade;
import com.ssafy.timo.domain.seat.entity.SeatStatus;
import com.ssafy.timo.domain.seat.entity.Section;

import java.util.List;

/**
 * 구역 하나의 좌석 목록 응답. 좌석 배치도를 그리는 화면이 쓴다.
 *
 * <p>등급과 가격은 좌석마다 다르지 않고 구역이 들고 있으므로, 좌석마다 반복해서 싣지 않고
 * 응답 머리에 한 번만 담는다.
 *
 * <p>페이지로 나누지 않는다. 배치도는 좌석이 전부 있어야 그려지고, 100 개씩 끊어 받으면 화면이
 * 여러 번 호출을 기다려야 해서 오히려 느리다. 대신 범위를 <b>구역 하나</b>로 묶어 응답 크기를
 * 공연장 전체가 아니라 구역 크기로 제한한다. 이 예외는 {@code BE_CODE_CONVENTION.md} 4장에 적혀 있다.
 */
public record SectionSeatListResponseDto(
        Long sectionId,
        String sectionName,
        SeatGrade grade,
        int price,
        int seatCount,
        int availableCount,
        Integer rowCount,
        Integer seatPerRow,
        List<SeatSummary> seats
) {

    public static SectionSeatListResponseDto from(Section section, List<Seat> seats) {
        List<SeatSummary> summaries = seats.stream()
                .map(SeatSummary::from)
                .toList();

        return new SectionSeatListResponseDto(
                section.getId(),
                section.getName(),
                section.getGrade(),
                section.getPrice(),
                summaries.size(),
                (int) summaries.stream()
                        .filter(seat -> seat.status() == SeatStatus.AVAILABLE)
                        .count(),
                section.getRowCount(),
                section.getSeatPerRow(),
                summaries);
    }

    /**
     * 좌석 한 자리.
     *
     * <p>구역 정보는 응답 머리에 이미 있으므로 좌석마다 다시 싣지 않는다.
     */
    public record SeatSummary(Long id, int seatNo, int seatCol, SeatStatus status) {

        static SeatSummary from(Seat seat) {
            return new SeatSummary(seat.getId(), seat.getSeatNo(), seat.getSeatCol(), seat.getStatus());
        }
    }
}
