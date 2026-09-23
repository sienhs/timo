package com.ssafy.timo.domain.captcha.controller;

import com.ssafy.timo.domain.captcha.dto.CaptchaIssueResponseDto;
import com.ssafy.timo.domain.captcha.dto.CaptchaVerifyRequestDto;
import com.ssafy.timo.domain.captcha.dto.CaptchaVerifyResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;

/**
 * 캡차 API 규약.
 *
 * <p>좌석 조회에 들어가기 전에 한 번 푸는 관문이다. 통과 기록은 서버가 들고 있고 클라이언트에
 * 토큰을 주지 않는다 - 토큰을 주면 그걸 복사해 여러 계정이 돌려 쓸 수 있다.
 */
public interface CaptchaApi {

    /**
     * 캡차를 하나 발급한다. 로그인이 필요하다 - 발급 기록을 회원 단위로 남겨야 남의 캡차를 주워
     * 쓰는 것과 무제한 발급을 둘 다 막을 수 있다.
     *
     * <p>201 이 아니라 200 이다. 이 호출이 만드는 것은 수명 2분짜리 임시 값이라 가리킬 주소가 없고,
     * 같은 요청을 다시 보내면 앞의 것과 무관한 새 캡차가 나온다.
     *
     * <p>공급자 호출이 실패하면 502 다.
     */
    @PostMapping
    ResponseEntity<CaptchaIssueResponseDto> issue(@CurrentMember Long memberId);

    /**
     * 발급받은 캡차를 검증하고, 맞으면 이 공연에 대한 통과 기록을 남긴다. 로그인이 필요하다.
     *
     * <p>키는 성공·실패와 무관하게 이 호출로 폐기된다 - 1회용이라 같은 키로 다시 검증할 수 없다.
     *
     * <p>없는 공연·없는 키는 404, 남의 키는 403, 오답은 400, 공급자 호출 실패는 502 다.
     */
    @PostMapping("/verify")
    ResponseEntity<CaptchaVerifyResponseDto> verify(@CurrentMember Long memberId,
                                                     @Valid @RequestBody CaptchaVerifyRequestDto request);
}
