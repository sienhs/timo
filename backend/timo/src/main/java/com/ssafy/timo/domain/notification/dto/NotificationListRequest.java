package com.ssafy.timo.domain.notification.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Positive;

/**
 * 알림 목록 요청. 커서 방식이라 페이지 번호가 없다.
 *
 * <p>알림은 위에서 계속 쌓이는 목록이라 페이지 번호로 넘기면 그 사이 온 새 알림 때문에 항목이 밀려
 * 같은 알림이 두 번 보이거나 건너뛴다. 그래서 직전 응답의 마지막 알림 id 를 {@code cursor} 로 받아
 * 그보다 오래된 것을 준다.
 *
 * @param cursor 직전 응답의 {@code nextCursor}. 없으면 가장 최근부터
 * @param size   한 번에 받을 개수. 없으면 {@value DEFAULT_SIZE}
 */
public record NotificationListRequest(
        @Positive(message = "cursor 는 1 이상이어야 합니다.")
        Long cursor,

        @Min(value = 1, message = "size 는 1 이상이어야 합니다.")
        @Max(value = MAX_SIZE, message = "size 는 " + MAX_SIZE + " 이하여야 합니다.")
        Integer size
) {
    public static final int DEFAULT_SIZE = 20;
    public static final int MAX_SIZE = 50;

    public int sizeOrDefault() {
        return size == null ? DEFAULT_SIZE : size;
    }

    /** 커서가 없으면 어떤 id 보다도 큰 값을 돌려줘, 조건 하나로 첫 페이지와 다음 페이지를 같이 다룬다. */
    public long cursorOrLatest() {
        return cursor == null ? Long.MAX_VALUE : cursor;
    }
}
