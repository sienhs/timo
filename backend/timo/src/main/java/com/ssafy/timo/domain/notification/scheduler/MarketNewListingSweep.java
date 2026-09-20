package com.ssafy.timo.domain.notification.scheduler;

import com.ssafy.timo.domain.concert.entity.ConcertStatus;
import com.ssafy.timo.domain.notification.entity.LinkType;
import com.ssafy.timo.domain.notification.entity.NotificationType;
import com.ssafy.timo.domain.notification.service.NotificationMessages;
import com.ssafy.timo.domain.notification.service.NotificationMessages.ListedConcert;
import com.ssafy.timo.domain.notification.service.NotificationRecorder;
import com.ssafy.timo.domain.notification.service.NotificationRecorder.Draft;
import com.ssafy.timo.domain.notification.service.TicketOwnerReader;
import com.ssafy.timo.domain.transfer.dto.NewListingRow;
import com.ssafy.timo.domain.transfer.repository.TicketListingRepository;
import com.ssafy.timo.domain.wish.dto.WishedConcertRow;
import com.ssafy.timo.domain.wish.repository.ConcertWishRepository;
import com.ssafy.timo.global.config.MarketHoursProperties;
import com.ssafy.timo.global.config.NotificationProperties;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.time.Duration;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 양도 마켓이 열릴 때, 찜한 공연에 어제 새 매물이 올라왔다고 알린다. 회원 한 명에게 하루 한 건이고, 여러
 * 공연이면 본문 한 통에 목록으로 묶는다.
 *
 * <pre>
 * 알림 시각  매일 마켓 여는 시각 (market.hours.open-at)
 * 새 매물    어제 00:00 이상 오늘 00:00 미만에 등록됐고 지금도 LISTED 인 매물
 * 대상       그 매물이 있는 공연을 찜한 회원
 * 제외       판매자 본인, 그 공연 티켓을 이미 가진 회원, 취소·종료된 공연, 시작이 2시간 안인 공연
 * 중복 방지  MARKET_NEW_LISTING:{yyyy-MM-dd}
 * 이동 화면  공연이 하나면 그 공연 상세, 여러 개면 마켓 목록
 * </pre>
 *
 * <p><b>"새 매물" 은 어제 등록된 매물이다.</b> 마켓은 오늘 00:00 이전에 등록된 매물만 남에게 보여 준다
 * ({@code MarketHoursService#visibleBefore}). 그래서 오늘 오픈에 처음 보이는 매물이 곧 어제 등록분이고, 발송을
 * 한 번 놓쳐도 이 기준은 흔들리지 않는다.
 *
 * <p>이 스윕만 조건의 모양이 다르다. 다른 셋은 "공연 시간 창" 을 찾지만 이 스윕은 "지금이 오픈 시각의 보정 구간
 * 안인가" 를 먼저 묻는다. 그래도 같은 {@link NotificationSweep} 인터페이스에 넣는다. 스케줄러가 알아야 할 것은
 * "지금 돌려 봐라" 하나뿐이고, 언제 무엇을 보낼지는 스윕이 정하는 것이 이 인터페이스의 약속이다. 창 밖이면 아무
 * 쿼리도 하지 않고 0 을 돌려준다.
 *
 * <p>오늘과 어제 두 발송일을 모두 본다. 오픈 시각이 밤 11시 반 같은 값이면 보정 구간이 자정을 넘어, 자정 뒤의
 * 주기가 어제의 발송을 마무리해야 하기 때문이다. 지금 설정(20:00)에서는 오늘 하나만 걸린다.
 *
 * <p>판매자와 티켓 보유자를 따로 뺀다. 판매자는 티켓을 보유한 상태로 매물을 올리므로 보유자 제외가 이미
 * 덮지만, 보유자 판정이 티켓 도메인의 몫이라 어긋나도 자기 매물 알림은 받지 않도록 판매자 제외를 명시한다.
 */
@Component
@RequiredArgsConstructor
public class MarketNewListingSweep implements NotificationSweep {

    /** 이 상태의 공연에는 보내지 않는다. 매진({@code SOLD_OUT}) 은 오히려 매물을 기다리는 사람이 가장 많다. */
    private static final List<ConcertStatus> EXCLUDED_STATUSES = List.of(ConcertStatus.CANCELED, ConcertStatus.CLOSED);

    /** 시작까지 이 시간 이하로 남은 공연은 뺀다. 마켓에서 더는 사기 어렵다. */
    static final Duration START_CUTOFF = Duration.ofHours(2);

    private final TicketListingRepository ticketListingRepository;
    private final ConcertWishRepository concertWishRepository;
    private final TicketOwnerReader ticketOwnerReader;
    private final NotificationRecorder notificationRecorder;
    private final MarketHoursProperties marketHours;
    private final NotificationProperties properties;

    @Override
    public String name() {
        return "MARKET_NEW_LISTING";
    }

    @Override
    public int run(LocalDateTime now, int limit) {
        LocalDateTime notBefore = now.minus(properties.catchUp());

        int recorded = 0;
        // 오래된 발송일부터 처리한다.
        for (LocalDate sendDate : List.of(now.toLocalDate().minusDays(1), now.toLocalDate())) {
            if (recorded >= limit) {
                break;
            }
            LocalDateTime sendAt = sendDate.atTime(marketHours.openAt());
            if (sendAt.isAfter(now) || sendAt.isBefore(notBefore)) {
                continue; // 이 발송일의 알림 시각이 아직 안 왔거나 보정 구간을 지났다.
            }
            recorded += recordFor(sendDate, now, limit - recorded);
        }
        return recorded;
    }

    private int recordFor(LocalDate sendDate, LocalDateTime now, int remaining) {
        List<NewListingRow> listings = ticketListingRepository.findNewListings(
                sendDate.minusDays(1).atStartOfDay(), sendDate.atStartOfDay(),
                EXCLUDED_STATUSES, now.plus(START_CUTOFF));
        if (listings.isEmpty()) {
            return 0;
        }

        Map<Long, ConcertWithListings> concerts = groupByConcert(listings);
        List<Long> concertIds = List.copyOf(concerts.keySet());

        Map<Long, Set<Long>> holders = ticketOwnerReader.findHolderMemberIds(concertIds).entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getKey, entry -> Set.copyOf(entry.getValue())));

        // 회원마다, 찜했고 판매자도 보유자도 아닌 공연만 모은다.
        Map<Long, List<ConcertWithListings>> concertsByMember = new LinkedHashMap<>();
        for (WishedConcertRow wish : concertWishRepository.findAllByConcertIdIn(concertIds)) {
            ConcertWithListings concert = concerts.get(wish.getConcertId());
            boolean isSeller = concert.sellerIds().contains(wish.getMemberId());
            boolean isHolder = holders.getOrDefault(wish.getConcertId(), Set.of()).contains(wish.getMemberId());
            if (!isSeller && !isHolder) {
                concertsByMember.computeIfAbsent(wish.getMemberId(), memberId -> new ArrayList<>()).add(concert);
            }
        }

        String dedupKey = NotificationType.MARKET_NEW_LISTING.dateKey(sendDate);
        List<Draft> drafts = concertsByMember.entrySet().stream()
                .map(entry -> draft(entry.getKey(), entry.getValue(), dedupKey))
                .toList();

        return SweepLimits.recordUpTo(drafts, remaining, notificationRecorder::recordAll);
    }

    /** 공연이 하나면 그 공연으로, 여러 개면 마켓 목록으로 보낸다. 마켓에는 찜한 공연 필터가 없어서다. */
    private static Draft draft(Long memberId, List<ConcertWithListings> concerts, String dedupKey) {
        List<ListedConcert> listed = concerts.stream()
                .map(concert -> new ListedConcert(concert.title(), concert.startDate()))
                .toList();
        String body = NotificationMessages.marketNewListing(listed);

        if (concerts.size() == 1) {
            return new Draft(memberId, NotificationType.MARKET_NEW_LISTING, body, LinkType.CONCERT,
                    concerts.get(0).concertId(), dedupKey);
        }
        return new Draft(memberId, NotificationType.MARKET_NEW_LISTING, body, LinkType.MARKET, null, dedupKey);
    }

    private static Map<Long, ConcertWithListings> groupByConcert(List<NewListingRow> listings) {
        Map<Long, ConcertWithListings> concerts = new LinkedHashMap<>();
        for (NewListingRow listing : listings) {
            concerts.computeIfAbsent(listing.getConcertId(), id -> new ConcertWithListings(
                            id, listing.getTitle(), listing.getStartDate(), new HashSet<>()))
                    .sellerIds().add(listing.getSellerMemberId());
        }
        return concerts;
    }

    /** 새 매물이 올라온 공연 하나와 그 매물을 올린 판매자들. */
    private record ConcertWithListings(Long concertId, String title, LocalDateTime startDate, Set<Long> sellerIds) {
    }
}
