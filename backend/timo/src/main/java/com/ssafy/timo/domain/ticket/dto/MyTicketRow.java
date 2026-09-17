package com.ssafy.timo.domain.ticket.dto;

import java.time.LocalDateTime;

/**
 * 내가 지금 가진 티켓 한 줄. 조회 전용 프로젝션이다.
 *
 * <p>소유자를 예매와 체결 이력을 합쳐 판정하느라 쿼리가 {@code union} 을 쓰는데, JPQL 은 이를
 * 지원하지 않아 네이티브 SQL 이다. 그래서 엔티티가 아니라 인터페이스로 받는다 —
 * <b>컬럼 별칭이 곧 메서드 이름이다.</b> enum 과 {@code boolean} 은 자동 변환되지 않아
 * 문자열과 정수로 받고 {@link MyTicketSummaryResponseDto} 가 옮긴다.
 */
public interface MyTicketRow {

    Long getTicketId();

    /** 발행한 예매. <b>양도받은 티켓이면 판 사람의 예매다</b> — {@link #getAcquiredBy()} 로 가린다. */
    Long getReservationId();

    Long getConcertId();

    String getConcertTitle();

    /** 저장소 키다. URL 변환은 {@code ImageStorage} 가 한다. */
    String getPosterImageKey();

    LocalDateTime getStartDate();

    String getVenueName();

    String getSectionName();

    /** 구역 안의 행 번호. {@code Seat} 의 이름 그대로다. */
    int getSeatNo();

    /** 행 안의 자리 번호. */
    int getSeatCol();

    /** 구역 정가. 양도 등록가의 상한이다. */
    long getFacePrice();

    /** {@code TicketStatus} 의 이름. 예매 상태가 아니다. */
    String getTicketStatus();

    /** {@code TicketAcquisition} 의 이름. */
    String getAcquiredBy();

    /** 내 것이 된 시각. 예매면 예매 시각, 양도면 체결 시각이다. */
    LocalDateTime getAcquiredAt();

    /** 양도 등록 중이면 1. {@code boolean} 으로 받으면 MySQL 의 0/1 을 변환하지 못해 터진다. */
    int getListed();
}
