package com.ssafy.timo.domain.transfer.dto;

import java.time.LocalDateTime;

/**
 * 내 거래 내역 한 줄. 판매({@code ticket_listing})와 구매({@code ticket_trade})를 {@code union all}
 * 로 합친 결과를 받는 조회 전용 프로젝션이다.
 *
 * <p>두 테이블을 합치는 쿼리는 JPQL 로 쓸 수 없어({@code union} 미지원) 네이티브 SQL 이다.
 * 그래서 엔티티가 아니라 이 인터페이스로 받는다 — 컬럼 별칭이 곧 이 메서드 이름이다.
 *
 * <p>{@code status} 를 문자열로 받는 이유는 판매면 {@code ListingStatus}, 구매면 {@code TradeStatus}
 * 라서 한 컬럼에 두 enum 이 섞이기 때문이다. 두 enum 의 값이 겹치지 않도록 만들어 두었고
 * ({@link MyTradeStatus} 의 6 값), 변환은 그쪽이 맡는다.
 *
 * <p>정렬 기준인 {@code occurredAt} 은 판매면 등록 시각, 구매면 체결 시각이다. 한 목록으로 합치려면
 * 정렬 기준이 되는 시각의 이름이 하나여야 한다.
 */
public interface MyTradeRow {

    /** {@code SALE} 또는 {@code PURCHASE}. {@link MyTradeType} 의 이름이다. */
    String getTradeType();

    /** 구매에만 값이 있다. 판매는 아직 팔리지 않았을 수 있어 체결 자체가 없다. */
    Long getTradeId();

    Long getListingId();

    /** {@link MyTradeStatus} 의 이름. 판매면 매물 상태, 구매면 온체인 전송 상태다. */
    String getStatus();

    Long getConcertId();

    String getConcertTitle();

    String getPosterImageKey();

    LocalDateTime getStartDate();

    String getVenueName();

    String getSectionName();

    /** {@code SeatGrade} 의 이름. */
    String getGrade();

    long getPrice();

    long getFaceValue();

    LocalDateTime getOccurredAt();
}
