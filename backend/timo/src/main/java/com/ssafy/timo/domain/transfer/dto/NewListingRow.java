package com.ssafy.timo.domain.transfer.dto;

import java.time.LocalDateTime;

/**
 * 새로 올라온 양도 매물 하나와 그 공연의 이름, 시작 시각. 새 매물 알림이 "어느 공연에 매물이 올라왔고 누가
 * 판 것인가" 를 한 번에 알기 위한 행이다. 판 사람은 자기 매물의 알림을 받지 않으므로 함께 담는다.
 */
public interface NewListingRow {

    Long getConcertId();

    String getTitle();

    LocalDateTime getStartDate();

    Long getSellerMemberId();
}
