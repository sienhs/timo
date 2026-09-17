package com.ssafy.timo.stub.transfer;

import com.ssafy.timo.stub.StubFixtures;
import com.ssafy.timo.stub.StubFixtures.MarketTicketFixture;
import com.ssafy.timo.stub.StubFixtures.SeatFixture;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Optional;

/**
 * 스텁이 아는 티켓 전부.
 *
 * <p><b>예매 스텁과 마켓 스텁이 같은 티켓을 봐야 해서 컨트롤러 밖으로 뺐다</b>({@code SeatStateStore} 와
 * 같은 사정이다). 원래는 마켓 스텁이 고정 티켓 6장을 혼자 들고 있었고 예매 스텁에는 티켓 개념이
 * 아예 없었다. 그래서 v0 에서는 <b>예매로 받은 번호로 양도 등록을 하면 404</b> 가 났다 - 두 스텁이
 * 서로 다른 세계를 보고 있었기 때문이다. 앱이 "예매 → 내 티켓 목록 → 양도 등록" 을 끝까지 눌러 볼 수
 * 없었던 원인이고, 이 저장소가 그 사이를 잇는다.
 *
 * <p>들고 있는 티켓은 두 종류다.
 *
 * <ul>
 *   <li><b>고정 티켓</b>({@link StubFixtures#MARKET_TICKETS}) - 남의 매물 5장과 내 보유 1장. 앱이
 *       예매를 하지 않아도 마켓 화면에 볼 것이 있어야 해서 처음부터 들어 있다</li>
 *   <li><b>예매로 생긴 티켓</b> - 예매 스텁이 주문을 만들 때 {@link #register} 로 넣는다.
 *       번호는 {@link StubFixtures#ORDER_TICKET_ID_START} 대역이라 고정 티켓과 겹치지 않는다</li>
 *   </ul>
 *
 * <p>실제 구조로는 {@code ticket} 테이블 하나에 해당한다. 예매가 티켓을 만들고 마켓이 그 티켓을
 * 읽는 관계가 v1 과 같아진다.
 */
@Component
@ConditionalOnProperty(prefix = "api.stub", name = "enabled", havingValue = "true")
public class MarketTicketStore {

    /** 등록 순서를 유지한다. 고정 티켓이 먼저, 예매로 생긴 티켓이 뒤에 온다. */
    private final Map<Long, MarketTicket> tickets = new LinkedHashMap<>();

    public MarketTicketStore() {
        for (MarketTicketFixture fixture : StubFixtures.MARKET_TICKETS) {
            SeatFixture seat = StubFixtures.findSeat(fixture.seatId()).orElseThrow();
            // 고정 데이터의 tokenId 는 십진 문자열이라 그대로 ticketId 로 쓴다.
            long ticketId = Long.parseLong(fixture.tokenId());
            tickets.put(ticketId, new MarketTicket(
                    ticketId, fixture.concertId(), seat, seat.section().price(), fixture.mine()));
        }
    }

    public Optional<MarketTicket> find(long ticketId) {
        return Optional.ofNullable(tickets.get(ticketId));
    }

    public Collection<MarketTicket> all() {
        return tickets.values();
    }

    /**
     * 예매로 생긴 티켓을 넣는다. 예매 스텁이 주문을 만들 때 부른다.
     *
     * <p>내 예매라서 언제나 내 티켓이다 - 스텁에는 요청자 개념이 없고, 주문을 넣은 쪽이 곧 나다.
     *
     * <p>정가는 마켓 스텁의 다른 티켓과 같은 기준인 구역 가격을 쓴다. 실제 구현도 정가 판정에
     * {@code Section.price} 를 본다({@code ListingService.faceValueOf}).
     *
     * <p>같은 번호가 다시 들어오는 일은 없다 - 주문마다 새 번호를 센다. 혹시 들어오더라도 먼저 넣은
     * 티켓을 지키고 무시한다. 덮어쓰면 그 티켓으로 열려 있던 매물이 주인 없는 상태가 된다.
     */
    public synchronized void register(long ticketId, long concertId, SeatFixture seat) {
        tickets.putIfAbsent(ticketId,
                new MarketTicket(ticketId, concertId, seat, seat.section().price(), true));
    }

    /**
     * 마켓이 아는 티켓 하나. 소유자와 등록 여부가 바뀌므로 가변이다.
     *
     * <p>실제 {@code Ticket} 과 모양이 다르다 - 그쪽은 소유자·공연·좌석을 직접 들지 않고
     * {@code reservation} 을 거치며, 소유자 컬럼 자체가 없다. 여기서는 스텁이 소유자를 바꿔야 해서
     * {@code mine} 을 직접 든다. 응답에 나가지 않는 이유이기도 하다.
     */
    public static final class MarketTicket {

        private final long ticketId;
        private final long concertId;
        private final SeatFixture seat;
        private final long faceValue;
        private boolean mine;
        private Long currentListingId;

        MarketTicket(long ticketId, long concertId, SeatFixture seat, long faceValue, boolean mine) {
            this.ticketId = ticketId;
            this.concertId = concertId;
            this.seat = seat;
            this.faceValue = faceValue;
            this.mine = mine;
        }

        long ticketId() {
            return ticketId;
        }

        long concertId() {
            return concertId;
        }

        SeatFixture seat() {
            return seat;
        }

        long faceValue() {
            return faceValue;
        }

        boolean mine() {
            return mine;
        }

        void changeOwnerToMe(boolean mine) {
            this.mine = mine;
        }

        Long currentListingId() {
            return currentListingId;
        }

        void currentListingId(Long listingId) {
            this.currentListingId = listingId;
        }

        boolean listed() {
            return currentListingId != null;
        }
    }
}
