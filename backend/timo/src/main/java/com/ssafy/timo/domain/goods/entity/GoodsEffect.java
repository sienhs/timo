package com.ssafy.timo.domain.goods.entity;

/**
 * 굿즈에 얹는 이펙트. 앱이 셰이더로 실시간 렌더링하는 이름표이고 서버는 값을 해석하지 않는다.
 *
 * <p>상수 이름이 곧 JSON 값이자 DB 값이다({@code stageLights} 처럼 camelCase). 앱이 보내는
 * 문자열을 그대로 저장·반환하려고 자바 관례(대문자)를 따르지 않았다. 그래서 {@code @JsonValue}
 * 없이도 Jackson 이 이름 그대로 읽고 쓴다.
 */
public enum GoodsEffect {
    confetti,
    laser,
    stageLights,
    curtain,
    godRays,
    none
}
