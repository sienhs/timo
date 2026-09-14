package com.ssafy.timo.domain.transfer.entity;

/**
 * 양도 체결의 온체인 전송 상태.
 *
 * <p>코인 전송과 NFT 소유권 이전은 DB 트랜잭션 밖에서 일어난다. DB 상 체결이 끝나도 온체인은
 * 아직인 구간이 있어 상태를 따로 들고 있어야 한다. 체결 API 가 200 이 아니라 202 인 이유다.
 *
 * <p><b>온체인 연동 전까지 모든 체결은 {@link #PENDING} 에 머문다.</b> {@link #CONFIRMED} 로 가는
 * 경로가 아직 없다.
 */
public enum TradeStatus {

    /** DB 체결은 끝났고 온체인 전송이 남은 상태. */
    PENDING,

    /** 온체인 전송까지 완료. */
    CONFIRMED,

    /** 온체인 전송 실패. */
    FAILED
}
