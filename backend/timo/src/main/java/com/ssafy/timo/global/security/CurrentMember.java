package com.ssafy.timo.global.security;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 요청자의 회원 id 를 컨트롤러 파라미터로 받는다.
 *
 * <pre>
 * ResponseEntity&lt;SeatHoldResponseDto&gt; hold(@PathVariable Long seatId, @CurrentMember Long memberId)
 * </pre>
 *
 * <p>값의 근거는 <b>검증된 access token 의 {@code sub} 하나뿐이다.</b> 경로·본문·쿼리·헤더로 회원
 * 식별자를 받지 않는다. 클라이언트가 보낸 값을 신원으로 쓰면 그 값을 바꿔 남의 자원에 접근할 수
 * 있고, 그것을 막으려면 "이 토큰의 주인이 이 식별자와 같은가" 를 호출마다 검사해야 하는데
 * <b>한 곳이라도 빠뜨리면 뚫린다.</b> 받지 않으면 그 실수가 애초에 불가능하다.
 *
 * <p><b>{@code @AuthenticationPrincipal(expression = "...")} 의 메타 애노테이션으로 만들지 않았다.</b>
 * 그렇게 하면 {@code sub} 를 꺼내 오기는 하지만 <b>거부를 못 한다.</b> 실제로 바꿔 돌려 보면
 * 토큰이 없을 때 500, {@code sub} 가 숫자가 아닐 때 500, 그리고 <b>선점 취소는 200</b> 이 나간다 —
 * 취소가 멱등이라 {@code memberId} 가 {@code null} 인 채로 "빈 자리 취소" 분기를 그대로 타기
 * 때문이다. 인증 없이 부른 요청에 200 과 403 이 갈려 나가면 그 자리가 선점 중인지까지 새어 나간다.
 *
 * <p>원인은 {@code AuthenticationPrincipalArgumentResolver} 의 순서에 있다. 인증 객체가
 * {@code null} 이면 <b>식을 평가하지도 않고</b> 곧장 {@code null} 을 돌려준다. 그래서 식 안에서
 * 우리 예외를 던지게 해도 "토큰 없음" 은 잡히지 않는다. {@code errorOnInvalidType} 도 타입 불일치용
 * 이라 {@code null} 에는 걸리지 않는다.
 *
 * <p>그래서 판정을 {@link CurrentMemberArgumentResolver} 가 직접 한다. 요청자를 특정할 수 없으면
 * 401 이다.
 */
@Documented
@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
public @interface CurrentMember {
}
