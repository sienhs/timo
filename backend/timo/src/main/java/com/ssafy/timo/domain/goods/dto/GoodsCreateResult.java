package com.ssafy.timo.domain.goods.dto;

/**
 * 생성 결과. {@link #created} 가 {@code true} 면 이번 호출이 만든 것(201), {@code false} 면 같은
 * {@code clientGoodsId} 재전송이라 저장하지 않고 기존 굿즈를 돌려준 것(200)이다.
 *
 * <p>상태 코드를 가르는 일은 컨트롤러 몫이라 서비스는 사실만 돌려준다.
 */
public record GoodsCreateResult(GoodsDetailResponseDto goods, boolean created) {
}
