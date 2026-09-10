package com.ssafy.timo.domain.auth.service;

import com.ssafy.timo.domain.auth.dto.ReissueResponseDto;
import com.ssafy.timo.domain.auth.entity.RefreshToken;
import com.ssafy.timo.domain.auth.repository.RefreshTokenRepository;
import com.ssafy.timo.domain.auth.service.AccessTokenProvider.AccessToken;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.global.security.exception.TokenInvalidException;
import com.ssafy.timo.global.util.Sha256;
import java.time.LocalDateTime;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * access 토큰 재발급. 세션을 끊는 쪽은 {@link LogoutService} 가 맡는다.
 *
 * <p><b>refresh 를 회전시키지 않는다.</b> 회전이 실제로 사주는 것은 무효화가 아니라 탈취 탐지인데,
 * 탐지(폐기된 토큰 재사용 감지)를 하지 않기로 한 이상 회전은 이득 없이 사고만 늘린다. 응답을 받고
 * 저장하기 전에 앱이 죽으면 멀쩡한 사용자가 로그아웃되고, 앱이 동시에 여러 요청을 보내면 늦게
 * 도착한 쪽이 무효 토큰을 들게 된다. refresh 를 서버가 끊을 수 있는 것은 회전이 아니라
 * <b>테이블에 저장돼 있기 때문</b>이고, 그건 회전 없이도 그대로다.
 *
 * <p>대신 재발급 때마다 만료를 다시 민다. 그러지 않으면 앱을 매일 쓰는 사용자도 최초 로그인에서
 * 센 수명이 다하는 날 그냥 튕긴다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class TokenReissueService {

    private final RefreshTokenRepository refreshTokenRepository;
    private final RefreshTokenProvider refreshTokenProvider;
    private final AccessTokenProvider accessTokenProvider;

    /**
     * refresh 토큰을 확인하고 새 access 토큰을 발급한다.
     *
     * <p>실패는 사유와 무관하게 전부 {@link TokenInvalidException}(401 {@code TOKEN_INVALID}) 이다.
     * 앱은 이 코드를 받으면 재발급을 재시도하지 않고 로그인 화면으로 간다. 여기서 사유를 나눠 봐야
     * 앱이 할 수 있는 일이 같고, 어느 토큰이 존재하는지만 알려주는 셈이 된다.
     */
    @Transactional
    public ReissueResponseDto reissue(String refreshToken, String deviceId) {
        RefreshToken session = refreshTokenRepository.findByTokenHash(Sha256.hex(refreshToken))
                .orElseThrow(() -> {
                    // 위조됐거나, 로그아웃으로 이미 지워진 세션이다.
                    log.warn("Reissue rejected: unknown token, deviceId={}", deviceId);
                    return new TokenInvalidException();
                });

        if (!session.getDeviceId().equals(deviceId)) {
            // 토큰이 발급된 기기가 아닌 곳에서 왔다. 정상 앱은 자기가 만든 UUID 를 계속 쓴다.
            log.warn("Reissue rejected: device mismatch, memberId={}, deviceId={}",
                    session.getMember().getId(), deviceId);
            throw new TokenInvalidException();
        }

        if (session.isExpired(LocalDateTime.now())) {
            // 어차피 못 쓰는 행이다. 남겨 두면 계속 쌓이기만 한다.
            refreshTokenRepository.delete(session);
            log.info("Reissue rejected: session expired, memberId={}", session.getMember().getId());
            throw new TokenInvalidException();
        }

        refreshTokenProvider.renew(session);

        Member member = session.getMember();
        AccessToken accessToken = accessTokenProvider.issue(member.getId(), member.getRole());

        log.info("Access token reissued: memberId={}, deviceId={}", member.getId(), deviceId);

        return new ReissueResponseDto(accessToken.value(), accessToken.expiresInSeconds());
    }
}
