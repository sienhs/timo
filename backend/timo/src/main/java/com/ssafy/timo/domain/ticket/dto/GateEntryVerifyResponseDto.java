package com.ssafy.timo.domain.ticket.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.seat.entity.Seat;
import com.ssafy.timo.global.util.PhoneNumbers;

/**
 * 게이트 검표 결과.
 *
 * <p><b>거절도 4xx 가 아니라 200 이다.</b> "들여보낼 수 없다" 는 정상적인 판정 결과이지 요청이
 * 잘못된 것이 아니다. 게이트 앱이 상태 코드를 해석하지 않고 {@code admitted} 만 보게 하려는 것이고
 * ({@code gate/README.md} 규약), 덕분에 앱은 4xx/5xx 를 전부 "판정 실패(네트워크·서버 문제)" 하나로
 * 다룰 수 있다.
 *
 * <p>좌석·예매자는 <b>정적 팩토리가 정하는 경우에만</b> 실린다. 어느 판정에 무엇이 실리는지를
 * 여기서 닫아 두지 않으면, 분기가 늘 때 개인정보가 실리는 경우가 조용히 번진다.
 *
 * @param admitted   입장 허용 여부
 * @param reasonCode 거절 사유. 허용이면 응답에 아예 나타나지 않는다
 * @param seat       지정 좌석. 허용과 {@code ALREADY_USED} 에만 있다
 * @param holder     예매자. 허용에만 있다
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public record GateEntryVerifyResponseDto(
        boolean admitted,
        GateRejectReason reasonCode,
        SeatInfo seat,
        HolderInfo holder) {

    /**
     * 운영자가 통과시킨 관람객에게 자리를 안내할 때 쓴다. 팬 앱
     * {@code ReservationSummaryResponseDto} 와 같은 세 값이라 화면 문구를 맞추기 쉽다.
     */
    public record SeatInfo(String sectionName, int seatNo, int seatCol) {

        public static SeatInfo from(Seat seat) {
            return new SeatInfo(seat.getSection().getName(), seat.getSeatNo(), seat.getSeatCol());
        }
    }

    /**
     * 예매자. <b>연락처는 서버에서 가려서 내린다</b> - 앱에 원문을 주고 앱이 가리면 프록시·접근
     * 로그를 원문 그대로 지나가 마스킹이 장식이 된다. 이름은 가리지 않는다(팀 결정).
     */
    public record HolderInfo(String name, String maskedPhoneNumber) {

        public static HolderInfo from(Member member) {
            return new HolderInfo(member.getName(), PhoneNumbers.mask(member.getPhoneNumber()));
        }
    }

    public static GateEntryVerifyResponseDto admit(SeatInfo seat, HolderInfo holder) {
        return new GateEntryVerifyResponseDto(true, null, seat, holder);
    }

    /** 중복 스캔. 좌석까지 주어 "이미 입장한 그 자리" 를 확인시켜 준다. */
    public static GateEntryVerifyResponseDto alreadyUsed(SeatInfo seat) {
        return new GateEntryVerifyResponseDto(false, GateRejectReason.ALREADY_USED, seat, null);
    }

    /** 그 밖의 거절. 티켓이 특정되지 않거나, 특정돼도 운영자가 좌석으로 할 일이 없다. */
    public static GateEntryVerifyResponseDto reject(GateRejectReason reasonCode) {
        return new GateEntryVerifyResponseDto(false, reasonCode, null, null);
    }
}
