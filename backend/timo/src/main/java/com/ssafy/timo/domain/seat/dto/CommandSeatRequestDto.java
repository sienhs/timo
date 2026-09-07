package com.ssafy.timo.domain.seat.dto;

import com.ssafy.timo.domain.seat.entity.SeatPosition;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * 좌석 등록 요청. 한 공연장의 구역들과 각 구역의 좌석을 함께 받는다.
 *
 * <p>구역을 하나씩 등록하는 대신 한 번에 받는다. 공연장의 좌석 배치는 한 번에 확정되는 것이고,
 * 중간에 실패했을 때 절반만 등록된 좌석 배치가 남으면 안 되기 때문이다. 구역 하나만 추가하는 경우는
 * 길이 1 의 목록으로 보내면 된다.
 *
 * <p>좌석 수는 받지 않는다. 나열한 좌석의 개수로 서버가 채운다. 클라이언트가 보낸 숫자를 그대로 믿으면
 * 실제 좌석 행 수와 어긋날 수 있다.
 *
 * <p>등급도 받지 않는다. 등급 구분이 아직 없어 모든 구역이 {@code COMMON} 이다.
 */
public record CommandSeatRequestDto(

        @NotNull(message = "공연장 ID는 필수입니다.")
        Long venueId,

        @NotEmpty(message = "구역은 최소 1개여야 합니다.")
        List<@NotNull(message = "구역 정보는 비어 있을 수 없습니다.") @Valid SectionLayout> sections
) {

    /**
     * 구역 하나의 좌석 배치.
     *
     * <p>좌석은 {@code seats} 에 자리를 나열해서만 등록된다. 실제 공연장은 통로로 비는 자리나 행마다 다른
     * 좌석 수가 흔해서 격자로 찍어내는 방식으로는 표현되지 않기 때문이다.
     *
     * <p>{@code rowCount}, {@code seatPerRow} 는 배치도를 그릴 때 쓰는 격자 크기이고 선택값이다.
     * 함께 오면 그 범위를 벗어나는 자리가 있는지 검사하는 기준이 되고, 생략하면 좌석 목록의 최대 번호에서
     * 뽑아낸다. 마지막 행만 짧은 구역처럼 좌석 목록이 격자의 끝까지 닿지 않는 배치에서는 직접 보내는 편이
     * 정확하다.
     *
     * <p>좌석 수와 행·자리 수에 상한을 두는 이유는 오타 한 번으로 수백만 행이 INSERT 되는 것을 막기
     * 위해서다. 국내 최대 규모 공연장도 구역 단위로는 이 범위를 넘지 않는다.
     */
    public record SectionLayout(

            @NotBlank(message = "구역명은 필수입니다.")
            @Size(max = 50, message = "구역명은 50자 이하여야 합니다.")
            String name,

            @PositiveOrZero(message = "좌석 가격은 0 이상이어야 합니다.")
            int price,

            @Positive(message = "행 수는 1 이상이어야 합니다.")
            @Max(value = 200, message = "행 수는 200 이하여야 합니다.")
            Integer rowCount,

            @Positive(message = "행당 좌석 수는 1 이상이어야 합니다.")
            @Max(value = 200, message = "행당 좌석 수는 200 이하여야 합니다.")
            Integer seatPerRow,

            @NotEmpty(message = "좌석은 최소 1개여야 합니다.")
            @Size(max = 40_000, message = "구역의 좌석은 40000개 이하여야 합니다.")
            List<@NotNull(message = "좌석 위치는 비어 있을 수 없습니다.") @Valid SeatPositionRequest> seats
    ) {

        /** 나열된 자리를 도메인 값으로 바꾼다. 순서는 받은 그대로 유지한다. */
        public List<SeatPosition> toPositions() {
            return seats.stream()
                    .map(SeatPositionRequest::toPosition)
                    .toList();
        }
    }

    /** 좌석 한 자리. 행 번호와 자리 번호 모두 1 부터 시작한다. */
    public record SeatPositionRequest(

            @NotNull(message = "행 번호는 필수입니다.")
            @Positive(message = "행 번호는 1 이상이어야 합니다.")
            Integer seatNo,

            @NotNull(message = "자리 번호는 필수입니다.")
            @Positive(message = "자리 번호는 1 이상이어야 합니다.")
            Integer seatCol
    ) {

        SeatPosition toPosition() {
            return new SeatPosition(seatNo, seatCol);
        }
    }
}
