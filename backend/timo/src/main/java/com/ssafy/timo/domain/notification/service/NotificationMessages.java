package com.ssafy.timo.domain.notification.service;

import com.ssafy.timo.domain.notification.entity.NotificationPhase;
import com.ssafy.timo.domain.notification.entity.NotificationType;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;

/**
 * 알림 본문을 만든다. 알림함에 저장되는 문자열과 푸시 본문이 같아야 하므로 문구는 여기서 한 번만
 * 만들고 양쪽이 그대로 쓴다.
 *
 * <p>한 줄 템플릿은 {@link NotificationType} 이 들고 있고, 여기서는 값을 채우기만 한다. 여러 공연을
 * 나열하는 마켓 알림만 목록을 직접 조립한다.
 *
 * <p>모든 본문은 공연명을 {@value #TITLE_LIMIT}자로 줄이므로 길이가 정해져 있다. 가장 긴 마켓 알림도
 * 500자 컬럼에 한참 못 미친다. 컬럼을 넘는 본문은 {@code INSERT IGNORE} 가 조용히 잘라 넣기 때문에
 * 이 상한이 깨지면 알 방법이 없다.
 */
public final class NotificationMessages {

    /** 공연명 한 개에 허용하는 글자 수. 넘으면 이만큼 자르고 {@value #ELLIPSIS} 를 붙인다. */
    static final int TITLE_LIMIT = 30;

    /** 마켓 알림에서 공연명을 몇 개까지 나열하는지. 넘는 만큼은 "외 N건" 으로 접는다. */
    static final int LIST_LIMIT = 3;

    private static final String ELLIPSIS = "…";
    private static final String BULLET = "· ";

    private NotificationMessages() {
    }

    /** 입장 가능. 예: {@code 로이킴 콘서트, 지금부터 입장할 수 있어요} */
    public static String entryOpen(String concertTitle) {
        return NotificationType.ENTRY_OPEN.template().formatted(clip(concertTitle));
    }

    /**
     * 예매 오픈 안내. 시점마다 문장 구조가 달라 템플릿도 시점별이다.
     * 예: {@code 로이킴 콘서트 예매가 내일 시작돼요}, {@code 로이킴 콘서트 예매 시작까지 1시간 남았어요}
     */
    public static String concertOpen(String concertTitle, NotificationPhase phase) {
        return NotificationType.CONCERT_OPEN_REMINDER.templateFor(phase).formatted(clip(concertTitle));
    }

    /**
     * 예매한 공연 일정. 시점마다 문장 구조가 달라 템플릿도 시점별이다.
     * 예: {@code 내일은 로이킴 콘서트 보는 날이에요}
     */
    public static String showReminder(String concertTitle, NotificationPhase phase) {
        return NotificationType.SHOW_REMINDER.templateFor(phase).formatted(clip(concertTitle));
    }

    /** 양도 판매 완료. 예: {@code 로이킴 콘서트 티켓이 판매됐어요}. 구매자를 알 수 있는 정보는 넣지 않는다. */
    public static String listingSold(String concertTitle) {
        return NotificationType.LISTING_SOLD.template().formatted(clip(concertTitle));
    }

    /**
     * 알림 신청한 공연의 양도 매물 알림. 공연이 하나면 한 줄이고, 여럿이면 첫 줄이 요약이다. 푸시가 접혀
     * 첫 줄만 보여도 뜻이 통하게 하려는 것이다.
     *
     * <pre>
     * 알림 신청한 공연 5건에 양도 매물이 올라왔어요
     * · 로이킴 콘서트
     * · Bruno Mars 내한공연
     * · 이승기 콘서트
     * · 외 2건
     * </pre>
     *
     * <p>공연은 임박한 순으로 나열한다. 곧 열리는 공연의 매물이 가장 급하기 때문이다. 같은 공연이
     * 두 번 들어오면 건수가 부풀므로 호출부가 공연 단위로 모아서 넘긴다.
     *
     * @throws IllegalArgumentException 공연이 하나도 없을 때 — 보낼 알림이 없어야 한다
     */
    public static String marketNewListing(List<ListedConcert> concerts) {
        if (concerts == null || concerts.isEmpty()) {
            throw new IllegalArgumentException("양도 매물 알림에는 공연이 하나 이상 필요하다");
        }
        if (concerts.size() == 1) {
            return NotificationType.MARKET_NEW_LISTING.template()
                    .formatted(clip(concerts.get(0).title()));
        }

        List<ListedConcert> soonestFirst = concerts.stream()
                .sorted(Comparator.comparing(ListedConcert::startDate))
                .toList();

        StringBuilder body = new StringBuilder("알림 신청한 공연 ")
                .append(concerts.size())
                .append("건에 양도 매물이 올라왔어요");
        soonestFirst.stream().limit(LIST_LIMIT)
                .forEach(c -> body.append('\n').append(BULLET).append(clip(c.title())));
        int rest = concerts.size() - LIST_LIMIT;
        if (rest > 0) {
            body.append('\n').append(BULLET).append("외 ").append(rest).append("건");
        }
        return body.toString();
    }

    /** 공연명이 길면 {@value #TITLE_LIMIT}자에서 자르고 말줄임표를 붙인다. 이모지가 반으로 갈리지 않게 코드포인트로 센다. */
    static String clip(String title) {
        Objects.requireNonNull(title, "공연명이 없다");
        if (title.codePointCount(0, title.length()) <= TITLE_LIMIT) {
            return title;
        }
        return title.substring(0, title.offsetByCodePoints(0, TITLE_LIMIT)) + ELLIPSIS;
    }

    /** 마켓 알림에 나열할 공연 하나. 정렬 기준인 공연 시작 시각을 함께 받는다. */
    public record ListedConcert(String title, LocalDateTime startDate) {
    }
}
