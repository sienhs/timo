package com.ssafy.timo.domain.notification.entity;

import lombok.AccessLevel;
import lombok.Getter;

import java.time.LocalDate;
import java.util.Map;

/**
 * 알림 종류. 이동 화면, 중복 방지 키의 접두어, 문구 템플릿을 한곳에 모았다.
 * 종류를 추가할 때 이 enum 만 고치면 되도록 하려는 것이다.
 *
 * <p>D-7·D-1 같은 시점 구분은 종류가 아니라 {@code dedup_key} 에 들어간다. 같은 종류가 시점마다
 * 한 번씩 나가야 하므로 시점이 키에 없으면 첫 알림 이후가 전부 중복으로 막힌다.
 *
 * <p>문구는 {@link String#format} 형식이고, 조립은 {@code NotificationMessages} 가 맡는다. 시점과
 * 무관하게 한 줄인 알림은 {@link #template()} 하나면 되지만, 예매 오픈 H-1과 공연 일정 3종은 시점마다
 * 문장 구조 자체가 달라 "템플릿 + 시점 라벨 끼워넣기"로 안 된다. 이런 종류는 {@link #templateFor(NotificationPhase)}
 * 로 시점별 템플릿을 따로 둔다. 문구는 기획에서 확정한 값이므로 임의로 통일하지 않는다.
 */
@Getter
public enum NotificationType {

    /** 공연 시작 2시간 전, 현재 티켓 보유자에게. 템플릿 인자는 공연명. */
    ENTRY_OPEN(LinkType.CONCERT, "ENTRY_OPEN",
            "%s, 지금부터 입장할 수 있어요"),

    /** 예매 오픈 D-7 · D-1 · H-1, 그 공연을 찜한 회원에게. 시점마다 템플릿 인자는 공연명 하나뿐이다. */
    CONCERT_OPEN_REMINDER(LinkType.CONCERT, "CONCERT_OPEN", Map.of(
            NotificationPhase.D7, "%s 예매가 일주일 뒤 시작돼요",
            NotificationPhase.D1, "%s 예매가 내일 시작돼요",
            NotificationPhase.H1, "%s 예매 시작까지 1시간 남았어요"
    )),

    /** 예매한 공연의 D-7 · D-1 · D-0, 현재 티켓 보유자에게. 시점마다 템플릿 인자는 공연명 하나뿐이다. */
    SHOW_REMINDER(LinkType.CONCERT, "SHOW_REMINDER", Map.of(
            NotificationPhase.D7, "%s까지 일주일 남았어요",
            NotificationPhase.D1, "내일은 %s 보는 날이에요",
            NotificationPhase.D0, "오늘 %s 즐길 준비 되셨나요?"
    )),

    /**
     * 찜한 공연에 어제 새 양도 매물이 올라왔을 때, 하루 한 건. 이동 화면은 공연이 하나면 공연 상세,
     * 여러 개면 마켓 목록이 될 수 있어 아직 확정되지 않았다. 템플릿은 공연이 하나일 때의 한 줄이다.
     */
    MARKET_NEW_LISTING(LinkType.MARKET, "MARKET_NEW_LISTING",
            "%s 양도 매물이 올라왔어요"),

    /**
     * 내가 올린 매물이 팔려 소유권 이전까지 끝났을 때, 판매자에게. 알림은 거래 한 건에 한 번이고 거래 상세로
     * 이동한다. 템플릿 인자는 공연명이다. 구매자를 알 수 있는 정보는 본문에 넣지 않는다. 판매자와 구매자는
     * 서로를 알 수 없어야 한다.
     *
     * <p>{@code PurchaseService} 가 체결 기록을 넣을 때 {@code ListingSoldNotifier} 로 내보낸다. 온체인 연동이
     * 붙으면 그 호출이 체결 확정 뒤로 옮겨진다.
     */
    LISTING_SOLD(LinkType.TRADE, "LISTING_SOLD",
            "%s 티켓이 판매됐어요");

    private final LinkType linkType;
    @Getter(AccessLevel.NONE)
    private final String dedupPrefix;
    @Getter(AccessLevel.NONE)
    private final String template;
    @Getter(AccessLevel.NONE)
    private final Map<NotificationPhase, String> phaseTemplates;

    NotificationType(LinkType linkType, String dedupPrefix, String template) {
        this.linkType = linkType;
        this.dedupPrefix = dedupPrefix;
        this.template = template;
        this.phaseTemplates = null;
    }

    NotificationType(LinkType linkType, String dedupPrefix, Map<NotificationPhase, String> phaseTemplates) {
        this.linkType = linkType;
        this.dedupPrefix = dedupPrefix;
        this.template = null;
        this.phaseTemplates = phaseTemplates;
    }

    /** 시점과 무관한 한 줄 템플릿. 시점별 템플릿을 쓰는 종류에서 부르면 잘못 쓴 것이다. */
    public String template() {
        if (template == null) {
            throw new IllegalStateException(name() + " 은 시점별 템플릿을 쓴다 — templateFor(phase) 를 써라");
        }
        return template;
    }

    /** 시점별 템플릿. 그 종류가 쓰지 않는 시점을 넘기면 잘못 쓴 것이다. */
    public String templateFor(NotificationPhase phase) {
        String found = phaseTemplates == null ? null : phaseTemplates.get(phase);
        if (found == null) {
            throw new IllegalArgumentException(name() + " 은 " + phase + " 시점 템플릿이 없다");
        }
        return found;
    }

    /** 공연 하나에 한 번 나가는 알림의 중복 방지 키. 예: {@code ENTRY_OPEN:concert=12}. */
    public String concertKey(Long concertId) {
        return dedupPrefix + ":concert=" + concertId;
    }

    /** 같은 공연에 시점별로 나가는 알림의 키. 예: {@code CONCERT_OPEN_D7:concert=12}. */
    public String concertKey(String phase, Long concertId) {
        return dedupPrefix + "_" + phase + ":concert=" + concertId;
    }

    /** 거래 한 건에 한 번 나가는 알림의 키. 예: {@code LISTING_SOLD:trade=5}. */
    public String tradeKey(Long tradeId) {
        return dedupPrefix + ":trade=" + tradeId;
    }

    /** 하루에 한 번 나가는 알림의 키. 예: {@code MARKET_NEW_LISTING:2026-09-20}. */
    public String dateKey(LocalDate date) {
        return dedupPrefix + ":" + date;
    }
}
