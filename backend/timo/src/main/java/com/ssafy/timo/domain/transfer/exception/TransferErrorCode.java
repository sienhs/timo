package com.ssafy.timo.domain.transfer.exception;

import com.ssafy.timo.global.exception.BaseErrorCode;
import lombok.Getter;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;

/**
 * 양도 마켓 에러 코드.
 *
 * <p>{@code TICKET_NOT_FOUND}·{@code NOT_TICKET_OWNER}·{@code TICKET_NOT_LISTABLE} 은 원래 티켓 도메인의
 * 것이다. 티켓 도메인이 없던 시절 여기 두었고, 지금은 도메인이 생겼지만 그쪽에 에러 코드 enum 이
 * 아직 없다. <b>TODO</b>: 티켓 도메인 담당과 합의해 옮긴다 — 남의 도메인 파일이라 임의로 만들지 않는다.
 *
 * <p>"이미 이 공연의 티켓을 보유하고 있습니다"(1인 1매)는 예매와 같은 규칙이라 예매 도메인의
 * {@code AlreadyReservedException} 을 그대로 쓴다. 같은 규칙이 두 코드로 갈리면 앱이 분기를 두 번 짜야 한다.
 *
 * <p>정가 초과가 {@link #LIST_PRICE_EXCEEDS_FACE_PRICE}(400) 와
 * {@link #TRADE_PRICE_EXCEEDS_FACE_VALUE}(422) 로 갈려 있다. enum 이 상태를 함께 들고 있어 같은 코드를
 * 상황에 따라 다른 상태로 내보낼 수 없기 때문이다. 등록은 사용자가 방금 입력한 값이 잘못된 것이라 400,
 * 체결은 저장된 데이터가 규칙을 어긴 것이라 422 다.
 */
@Getter
@RequiredArgsConstructor
public enum TransferErrorCode implements BaseErrorCode {

    TICKET_NOT_FOUND(HttpStatus.NOT_FOUND, "존재하지 않는 티켓입니다."),
    /** 온체인 {@code NotTicketOwner}. */
    NOT_TICKET_OWNER(HttpStatus.FORBIDDEN, "본인이 보유한 티켓이 아닙니다."),
    /**
     * 온체인 {@code UnexpectedStatus(required=OWNED)}.
     *
     * <p>DB 로는 {@code ticket.status != OWNED} 인 경우가 전부 여기로 걸린다 — 이미 등록 중
     * ({@code LISTED}), 입장 완료({@code USED}), 회수됨({@code REVOKED}) 뿐 아니라 <b>아직 발행되지
     * 않은 티켓</b>({@code PENDING_MINT} · {@code MINT_FAILED} · {@code REFUNDED})도 포함한다.
     * 발행 전 티켓은 {@code tokenId} 가 없어 온체인에 올릴 대상 자체가 없다.
     */
    TICKET_NOT_LISTABLE(HttpStatus.CONFLICT, "양도 등록할 수 있는 상태의 티켓이 아닙니다."),
    /** 온체인 {@code ListPriceExceedsFacePrice}. "등록가가 정가 이하일 때에만 등록이 성립한다." */
    LIST_PRICE_EXCEEDS_FACE_PRICE(HttpStatus.BAD_REQUEST, "등록가는 정가를 초과할 수 없습니다."),
    LISTING_NOT_FOUND(HttpStatus.NOT_FOUND, "등록된 양도 매물이 아닙니다."),
    /**
     * 없는 거래이거나 <b>남의 거래</b>. 둘을 구분하지 않는다. 거래는 판매자와 구매자 둘만의 기록이라
     * 존재 여부 자체가 정보이고, 번호가 순차라 403 으로 가르면 체결 건수가 샌다.
     */
    TRADE_NOT_FOUND(HttpStatus.NOT_FOUND, "거래 내역을 찾을 수 없습니다."),
    CANNOT_BUY_OWN_LISTING(HttpStatus.CONFLICT, "본인이 등록한 매물은 구매할 수 없습니다."),

    /** 남의 매물을 취소하려 한 경우. 티켓 소유자가 아니라 <b>매물 판매자</b>가 아닌 것이다. */
    NOT_LISTING_SELLER(HttpStatus.FORBIDDEN, "본인이 등록한 매물이 아닙니다."),
    /**
     * 이미 팔렸거나 취소된 매물. 조건부 UPDATE 의 영향 행이 0 일 때 던진다.
     *
     * <p>선착순 경쟁에서 진 쪽이 받는 응답이기도 하다. 404 가 아닌 이유는 매물이 없는 게 아니라
     * 상태가 맞지 않는 것이고, 앱이 "없는 매물"과 "방금 팔린 매물"을 다르게 안내해야 하기 때문이다.
     */
    LISTING_ALREADY_CLOSED(HttpStatus.CONFLICT, "이미 종료된 매물입니다."),
    /** 구매자가 화면에서 본 가격과 서버의 등록가가 다른 경우. 목록 캐시와 상세 진입 사이의 시차에서 생긴다. */
    LISTING_PRICE_MISMATCH(HttpStatus.CONFLICT, "매물 가격이 변경되었습니다. 다시 확인해 주세요."),
    /**
     * 체결 시점 정가 재검증 실패.
     *
     * <p>{@code face_value} 는 등록 시점 스냅샷이라 불변이므로 정상 경로에서는 발생하지 않는다.
     * 데이터가 손상됐을 때만 걸리는 방어선이다. 그래도 검증을 두는 것은 정가 초과 판매 차단이
     * 이 서비스의 존재 이유이기 때문이다.
     */
    TRADE_PRICE_EXCEEDS_FACE_VALUE(HttpStatus.UNPROCESSABLE_CONTENT, "정가를 초과한 매물은 체결할 수 없습니다."),
    /**
     * 운영 시간 밖에 등록·가격 수정·구매를 시도한 경우. 판정은 서버 시계다.
     *
     * <p>403 이 아닌 이유는 요청자의 권한 문제가 아니라 시각이라는 상태의 문제이고, 기다리면
     * 같은 요청이 그대로 통과하기 때문이다. 취소와 조회는 시간과 무관하게 받는다.
     */
    MARKET_CLOSED(HttpStatus.CONFLICT, "양도 마켓 운영 시간이 아닙니다."),
    /**
     * 운영 시간 중에 등록가를 바꾸려 한 경우. {@link #MARKET_CLOSED} 의 반대다.
     *
     * <p>거래가 열려 있는 동안은 가격이 고정이다. 구매자가 목록에서 본 값이 상세에 들어갈 때까지
     * 바뀌지 않아야 하고, 마감 뒤에 바꾸면 다음 창에 새 가격으로 올라간다.
     */
    MARKET_OPEN(HttpStatus.CONFLICT, "운영 시간 중에는 등록가를 바꿀 수 없습니다."),
    /**
     * 아직 마켓에 올라오지 않은 매물을 사려 한 경우. 매물은 등록 다음 날 08:00 에 올라간다.
     *
     * <p>목록에는 안 보이지만 매물 번호를 알면 상세와 구매 경로로 닿을 수 있어 구매 쪽에서 막는다.
     * 판매자가 번호를 건네 하루 먼저 파는 통로가 되면 안 된다.
     */
    LISTING_NOT_OPEN_YET(HttpStatus.CONFLICT, "아직 마켓에 올라오지 않은 매물입니다."),
    /**
     * 온체인 체결(Marketplace.buy)이 실패한 경우. revert·일시적 오류를 가리지 않는다 - 이 시점엔
     * DB를 아무것도 바꾸기 전이라({@code PurchaseService}) 재시도하면 그대로 다시 시도될 뿐이다.
     */
    TRANSFER_FAILED(HttpStatus.CONFLICT, "구매 처리에 실패했습니다. 잠시 후 다시 시도해 주세요.");

    private final HttpStatus status;
    private final String message;
}
