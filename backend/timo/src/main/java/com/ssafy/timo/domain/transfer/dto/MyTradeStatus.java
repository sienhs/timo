package com.ssafy.timo.domain.transfer.dto;

import com.ssafy.timo.domain.transfer.entity.ListingStatus;
import com.ssafy.timo.domain.transfer.entity.TradeStatus;

/**
 * 내 거래 내역 항목의 상태. 매물 상태와 체결 상태를 합친 응답 전용 enum 이다.
 *
 * <p>{@link ListingStatus} 와 {@link TradeStatus} 를 그대로 섞어 내보내지 않는 이유는, 그러면
 * 클라이언트가 <b>{@code type} 을 먼저 분기해야 상태 필드를 파싱할 수 있기</b> 때문이다.
 * 값을 하나의 집합으로 합치면 파싱은 한 번이고 표기만 분기하면 된다.
 *
 * <p>{@link MyTradeType#SALE} 에는 {@link #LISTED} · {@link #SOLD} · {@link #CANCELED} 만,
 * {@link MyTradeType#PURCHASE} 에는 {@link #PENDING} · {@link #CONFIRMED} · {@link #FAILED} 만 온다.
 * 반대 조합은 생기지 않는다.
 */
public enum MyTradeStatus {

    /** (SALE) 구매 가능. 아직 팔리지 않았다. */
    LISTED,
    /** (SALE) 팔렸다. */
    SOLD,
    /** (SALE) 내가 등록을 취소했다. */
    CANCELED,

    /** (PURCHASE) DB 체결은 끝났고 온체인 전송이 남았다. */
    PENDING,
    /** (PURCHASE) 온체인 전송까지 완료. */
    CONFIRMED,
    /** (PURCHASE) 온체인 전송 실패. */
    FAILED;

    public static MyTradeStatus of(ListingStatus status) {
        return switch (status) {
            case LISTED -> LISTED;
            case SOLD -> SOLD;
            case CANCELED -> CANCELED;
        };
    }

    public static MyTradeStatus of(TradeStatus status) {
        return switch (status) {
            case PENDING -> PENDING;
            case CONFIRMED -> CONFIRMED;
            case FAILED -> FAILED;
        };
    }
}
