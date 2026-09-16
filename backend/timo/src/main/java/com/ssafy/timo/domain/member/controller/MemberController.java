package com.ssafy.timo.domain.member.controller;

import com.ssafy.timo.domain.member.dto.MemberMeResponseDto;
import com.ssafy.timo.domain.member.service.MemberService;
import com.ssafy.timo.domain.wallet.dto.ChargeWalletRequestDto;
import com.ssafy.timo.domain.wallet.dto.WalletSummaryResponseDto;
import com.ssafy.timo.domain.wallet.service.WalletChargeService;
import com.ssafy.timo.global.security.CurrentMember;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.CacheControl;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@Slf4j
@RestController
@RequestMapping(MemberController.BASE_PATH)
@RequiredArgsConstructor
public class MemberController {

    static final String BASE_PATH = "/api/v1/members";

    private final MemberService memberService;
    private final WalletChargeService walletChargeService;

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

    /** 내 지갑 잔액과 최근 거래 내역. */
    @GetMapping("/wallet")
    public ResponseEntity<WalletSummaryResponseDto> getWallet(@CurrentMember Long memberId) {
        return ResponseEntity.ok()
                .cacheControl(CacheControl.noStore())
                .body(walletChargeService.getSummary(memberId));
    }

    /**
     * 지갑을 충전한다. 실제 PG 연동 전까지는 이 요청 자체를 "결제 확인됨" 으로 간주하고
     * 곧바로 체인에 반영한다.
     */
    @PostMapping("/wallet/charge")
    public ResponseEntity<WalletSummaryResponseDto> chargeWallet(@Valid @RequestBody ChargeWalletRequestDto request,
                                                                 @CurrentMember Long memberId) {
        return ResponseEntity.ok(walletChargeService.charge(memberId, request.amount()));
    }
}
