package com.ssafy.timo.domain.auth.service;

import com.ssafy.timo.domain.auth.repository.RefreshTokenRepository;
import com.ssafy.timo.global.util.Sha256;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 로그아웃. 그 기기의 refresh 세션을 끊는다.
 *
 * <p>{@link TokenReissueService} 와 입력은 같지만 하는 일이 반대다. 재발급은 토큰을 내주고
 * 로그아웃은 지운다. 그래서 의존성도 저장소 하나뿐이고 토큰 발급기가 필요 없다.
 *
 * <p><b>access 토큰은 끊지 못한다.</b> JWT 라 서버가 되돌릴 수단이 없어 남은 수명(최대 30분)
 * 동안 그대로 통한다. 앱은 저장된 토큰을 반드시 지워야 하고, 지갑 서명처럼 민감한 작업을
 * access 만으로 통과시키면 안 되는 이유가 이것이다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class LogoutService {

    private final RefreshTokenRepository refreshTokenRepository;

    /**
     * 그 기기의 세션을 끊는다.
     *
     * <p>세션이 없어도 성공으로 친다. 로그아웃은 "끊긴 상태로 만들어 달라" 는 요청이고 그 상태는
     * 이미 달성돼 있다. 실패로 돌려주면 앱이 로그아웃 화면에서 멈추고, 어느 토큰이 살아 있는지를
     * 알려주는 신호도 된다.
     */
    @Transactional
    public void logout(String refreshToken, String deviceId) {
        refreshTokenRepository.findByTokenHash(Sha256.hex(refreshToken))
                .ifPresent(session -> {
                    refreshTokenRepository.delete(session);
                    log.info("Logged out: memberId={}, deviceId={}", session.getMember().getId(), deviceId);
                });
    }
}
