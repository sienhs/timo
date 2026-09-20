package com.ssafy.timo.domain.ticket.service;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.reservation.entity.Reservation;
import com.ssafy.timo.domain.ticket.dto.EntryPassResponseDto;
import com.ssafy.timo.domain.ticket.entity.Ticket;
import com.ssafy.timo.domain.ticket.entity.TicketStatus;
import com.ssafy.timo.domain.ticket.exception.EntryWindowClosedException;
import com.ssafy.timo.domain.ticket.exception.EntryWindowNotOpenException;
import com.ssafy.timo.domain.ticket.exception.TicketNotFoundException;
import com.ssafy.timo.domain.ticket.exception.TicketStatusNotIssuableException;
import com.ssafy.timo.domain.ticket.repository.TicketRepository;
import java.time.Clock;
import java.time.Duration;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
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
@Slf4j
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
     * 공연 시작 뒤 언제까지 내줄지. 지각 입장만 감안한 폭이다.
     *
     * <p>재입장은 이 폭과 상관이 없다. 게이트가 통과시키는 순간 티켓을 {@code USED} 로 태우므로
     * ({@code GateEntryService.verify}) 두 번째 스캔은 창이 열려 있어도 {@code ALREADY_USED} 로
     * 거절된다. 창을 넓혀 봐야 재입장이 열리지는 않는다.
     *
     * <p>발급이 닫힌 뒤에도 마지막에 나간 QR 은 수명({@code entry-pass.ttl}, 30초)만큼 게이트에서
     * 더 통한다. 게이트는 시간을 따로 보지 않기 때문이다. 실제로 입장이 막히는 순간은 시작 +5분이
     * 아니라 +5분 30초다. 창을 이만큼 좁히면 이 30초가 창의 10% 라, 운영상 더 좁힐 수 없는 하한이
     * 여기라는 뜻이기도 하다.
     *
     * <p>{@code Concert.endDate} 를 쓰지 않는다. 여러 날에 걸친 공연이면 종료일이 며칠 뒤라
     * 그 기간 내내 발급 창이 열린 채로 남는다. 시작 시각 기준이 언제나 더 좁다.
     */
    static final Duration ENTRY_CLOSES_AFTER_START = Duration.ofMinutes(5);

    private final TicketRepository ticketRepository;
    private final EntryPassProvider entryPassProvider;
    private final Clock clock;

    public EntryPassResponseDto issue(Long memberId, Long ticketId) {
        Ticket ticket = ticketRepository.findById(ticketId)
                .orElseThrow(() -> new TicketNotFoundException(ticketId));

        Reservation reservation = ticket.getReservation();
        if (ticketRepository.countCurrentOwnership(memberId, ticketId) == 0) {
            // 최초 예매자가 아니라 지금 소유자로 판정한다 - 양도로 주인이 바뀌면 판 사람은 더 이상
            // 발급받을 수 없다. 남의 티켓은 "권한 없음" 이 아니라 "없음" 이다(TicketNotFoundException 주석).
            throw new TicketNotFoundException(ticketId);
        }

        if (ticket.getStatus() != TicketStatus.OWNED) {
            // 발행 전(PENDING_MINT)·이미 입장(USED)·회수(REVOKED)·양도 등록 중(LISTED) 전부 여기서 걸린다.
            // 예매를 취소하면 티켓도 같은 트랜잭션에서 REVOKED 가 되므로 주문 상태는 따로 보지 않는다.
            // 어떤 상태였는지는 사용자에게 알릴 이유가 없는 내부 값이라 로그로만 남긴다.
            log.debug("입장 QR 발급 불가 - 티켓 상태 (ticketId={}, status={})", ticketId, ticket.getStatus());
            throw new TicketStatusNotIssuableException();
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
            log.debug("입장 QR 발급 불가 - 아직 발급 시간 전 (ticketId={}, startDate={})", ticketId, startDate);
            throw new EntryWindowNotOpenException();
        }
        if (now.isAfter(startDate.plus(ENTRY_CLOSES_AFTER_START))) {
            log.debug("입장 QR 발급 불가 - 발급 시간 종료 (ticketId={}, startDate={})", ticketId, startDate);
            throw new EntryWindowClosedException();
        }
    }
}
