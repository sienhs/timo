package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.ticket.dto.EntryPassResponseDto;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.exception.EntryPassNotIssuableException;
import com.ssafy.timo.domain.ticket.exception.TicketNotFoundException;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 입장 QR 발급.
 *
 * <p>서명은 {@link EntryPassProvider} 가 하고, 이 서비스는 <b>서명해도 되는 요청인지</b>만 가린다.
 * 셋을 본다: 내 티켓인가, 입장할 수 있는 상태인가, 지금이 입장 시간대인가.
 *
 * <p>아무것도 저장하지 않는다. 발급은 순수 조회 + 서명이라 같은 티켓으로 몇 번을 불러도 서버 상태가
 * 바뀌지 않는다. "이 티켓이 입장했다" 를 기록하는 일은 게이트 검증 쪽 몫이다.
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class EntryPassService {

    /**
     * 공연 시작 몇 시간 전부터 QR 을 내줄지.
     *
     * <p>입장 줄이 서기 전에 미리 화면을 띄워 볼 수 있어야 하지만, 몇 주 전부터 내줄 이유는 없다.
     * 일찍 열어 둘수록 "언제든 QR 을 받아 둘 수 있다" 는 가정이 생겨 캡처 전달을 부추긴다.
     */
    static final Duration ENTRY_OPENS_BEFORE_START = Duration.ofHours(2);

    /**
     * 공연 시작 뒤 언제까지 내줄지. 지각 입장과 재입장을 감안한 폭이다.
     *
     * <p>{@code Concert.endDate} 를 쓰지 않는다. 여러 날에 걸친 공연이면 종료일이 며칠 뒤라
     * 그 기간 내내 발급 창이 열린 채로 남는다. 시작 시각 기준이 언제나 더 좁다.
     */
    static final Duration ENTRY_CLOSES_AFTER_START = Duration.ofHours(6);

    private final TicketRepository ticketRepository;
    private final EntryPassProvider entryPassProvider;
    private final Clock clock;

    public EntryPassResponseDto issue(Long memberId, Long ticketId) {
        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new TicketNotFoundException(ticketId));

        Reservation reservation = ticket.getReservation();
        if (!reservation.isOwnedBy(memberId)) {
            // 남의 티켓은 "권한 없음" 이 아니라 "없음" 이다. TicketNotFoundException 주석 참고.
            throw new TicketNotFoundException(ticketId);
        }

        if (ticket.getStatus() != TicketStatus.OWNED) {
            // 발행 전(PENDING_MINT)·이미 입장(USED)·회수(REVOKED)·양도 등록 중(LISTED) 전부 여기서 걸린다.
            // 예매를 취소하면 티켓도 같은 트랜잭션에서 REVOKED 가 되므로 주문 상태는 따로 보지 않는다.
            throw new EntryPassNotIssuableException(ticketId, "입장할 수 있는 상태가 아닙니다 (status=" + ticket.getStatus() + ")");
        }

        requireWithinEntryWindow(ticketId, reservation.getConcert());

        return EntryPassResponseDto.from(entryPassProvider.issue(ticketId));
    }

    private void requireWithinEntryWindow(Long ticketId, Concert concert) {
        LocalDateTime startDate = concert.getStartDate();
        if (startDate == null) {
            // 일정이 아직 안 잡힌 공연. 예매 취소 컷오프도 같은 방식으로 비켜 간다.
            return;
        }

        LocalDateTime now = LocalDateTime.now(clock);
        if (now.isBefore(startDate.minus(ENTRY_OPENS_BEFORE_START))) {
            throw new EntryPassNotIssuableException(ticketId, "아직 입장 시간이 아닙니다 (startDate=" + startDate + ")");
        }
        if (now.isAfter(startDate.plus(ENTRY_CLOSES_AFTER_START))) {
            throw new EntryPassNotIssuableException(ticketId, "입장 시간이 지났습니다 (startDate=" + startDate + ")");
        }
    }
}
