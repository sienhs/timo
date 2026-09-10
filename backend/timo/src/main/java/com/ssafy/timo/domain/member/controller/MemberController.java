package com.ssafy.timo.domain.member.controller;

import com.ssafy.timo.domain.member.dto.MemberMeResponseDto;
import com.ssafy.timo.domain.member.service.MemberService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping(MemberController.BASE_PATH)
@RequiredArgsConstructor
public class MemberController {

    static final String BASE_PATH = "/api/v1/members";

    private final MemberService memberService;

    /**
     * 본인 정보 조회
     *
     * <p>{@code no-store} 를 붙이는 이유가 있다. 개인정보가 담긴 응답이라 프록시나 브라우저
     * 캐시에 남으면 같은 기기를 쓰는 다른 사람이 꺼내 볼 수 있다.
     */
    @GetMapping("/me")
    public ResponseEntity<MemberMeResponseDto> getMyInfo() {
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .body(memberService.getMyInfo());
    }
}
