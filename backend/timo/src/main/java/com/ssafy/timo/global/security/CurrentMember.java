package com.ssafy.timo.global.security;

import java.lang.annotation.Documented;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * 요청자의 회원 id를 검증된 access token의 {@code sub}에서만 꺼낸다. 경로·본문·쿼리·헤더로는
 * 받지 않는다 - 클라이언트가 보낸 값을 신원으로 쓰면 남의 자원에 접근할 길이 열린다.
 *
 * <pre>
 * ResponseEntity&lt;SeatHoldResponseDto&gt; hold(@PathVariable Long seatId, @CurrentMember Long memberId)
 * </pre>
 *
 * <p>{@code @AuthenticationPrincipal(expression = "...")}의 메타 애노테이션으로 만들지 않은
 * 이유: 인증 객체가 없으면 그 리졸버는 식을 평가하지도 않고 곧장 {@code null}을 반환해 거부를
 * 못 한다(예: 토큰 없이 부른 선점 취소가 {@code memberId=null}로 "빈 자리 취소" 분기를 타
 * 200이 나감 - 인증 여부가 응답 코드로 새어 나간다). 그래서 {@link CurrentMemberArgumentResolver}가
 * 직접 판정한다: 요청자를 특정할 수 없으면 401.
 */
@Documented
@Target(ElementType.PARAMETER)
@Retention(RetentionPolicy.RUNTIME)
public @interface CurrentMember {
}
