package com.ssafy.timo.domain.goods.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/**
 * 굿즈(소장품) 에러 코드.
 *
 * <p>{@link #GOODS_TICKET_NOT_OWNED} 가 403 이 아니라 <b>404</b> 인 이유: 403 은 "그 번호의 티켓은
 * 있다" 를 알려주는 셈이라 번호를 훑으면 누가 무엇을 예매했는지 셀 수 있다. 티켓·주문 조회
 * ({@code TicketErrorCode.TICKET_NOT_FOUND}) 와 같은 규칙이다. 남의 굿즈도 같은 이유로
 * {@link #GOODS_NOT_FOUND} 다.
 */
@Getter
@RequiredArgsConstructor
public enum GoodsErrorCode implements BaseErrorCode {

    /** 없거나 남의 굿즈. 존재 여부를 알리지 않는다. */
    GOODS_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 굿즈입니다."),

    /** 없거나 지금 내가 가진 티켓이 아니다. 존재 여부를 알리지 않으려고 404 다. */
    GOODS_TICKET_NOT_OWNED(HttpStatus.NOT_FOUND, "존재하지 않는 티켓입니다."),

    /** 내 티켓은 맞지만 아직 입장하지 않았다(또는 발행 전·회수·환불). */
    GOODS_TICKET_NOT_USED(HttpStatus.CONFLICT, "입장을 완료한 티켓으로만 굿즈를 만들 수 있습니다."),

    /** 이 티켓의 굿즈가 이미 있는데 다른 요청으로 또 만들려 했다. */
    GOODS_ALREADY_EXISTS(HttpStatus.CONFLICT, "이미 굿즈를 만든 티켓입니다."),

    /** {@code personLayers} 가 배열이 아니거나, 3개 이상이거나, {@code layerOrder} 가 겹친다. */
    GOODS_INVALID_LAYERS(HttpStatus.BAD_REQUEST, "인물 레이어 구성이 올바르지 않습니다.");

    private final HttpStatus status;
    private final String message;
}
