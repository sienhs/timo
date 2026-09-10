package com.ssafy.timo.domain.auth.repository;

import com.ssafy.timo.domain.auth.entity.RefreshToken;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    /** 기기당 세션은 하나다. 재발급도 로그인도 이 조회로 시작한다. */
    Optional<RefreshToken> findByMemberIdAndDeviceId(Long memberId, String deviceId);

    /**
     * 재발급·로그아웃용 조회.
     *
     * <p>refresh 토큰은 그냥 난수라 <b>토큰만 봐서는 주인을 알 수 없다.</b> access 토큰처럼
     * {@code sub} 가 들어 있지 않아 {@code memberId} 로 찾을 수가 없고, 클라이언트가 보내게 하면
     * 남의 번호를 보낼 수 있어 논외다. 그래서 해시로 직접 찾는다.
     */
    Optional<RefreshToken> findByTokenHash(String tokenHash);
}
