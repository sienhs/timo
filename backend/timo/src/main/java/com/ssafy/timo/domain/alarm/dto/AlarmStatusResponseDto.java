package com.ssafy.timo.domain.alarm.dto;

import com.ssafy.timo.domain.alarm.entity.AlarmType;

import java.util.Collection;

/**
 * 한 공연에 대한 내 알림 신청 상태. 종류마다 신청했는지를 준다.
 *
 * <p>공연 상세는 로그인 없이 열려 있어 요청자별 값을 실을 수 없으므로 신청 상태는 이 응답으로 따로 묻는다.
 * 버튼의 켜짐과 꺼짐을 그리려는 값이라 신청하지 않은 종류도 {@code false} 로 빠짐없이 준다.
 *
 * @param concertOpen   예매 오픈 안내({@link AlarmType#CONCERT_OPEN}) 를 신청했는가
 * @param marketListing 양도 매물 안내({@link AlarmType#MARKET_LISTING}) 를 신청했는가
 */
public record AlarmStatusResponseDto(boolean concertOpen, boolean marketListing) {

    /** 신청한 종류들로 만든다. 없는 종류는 {@code false} 다. */
    public static AlarmStatusResponseDto from(Collection<AlarmType> subscribed) {
        return new AlarmStatusResponseDto(
                subscribed.contains(AlarmType.CONCERT_OPEN),
                subscribed.contains(AlarmType.MARKET_LISTING));
    }
}
