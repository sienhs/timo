package com.ssafy.timo.domain.auth.repository;

import com.ssafy.timo.domain.auth.entity.RefreshToken;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, Long> {

    /** 기기당 세션은 하나다. 재발급도 로그인도 이 조회로 시작한다. */
    Optional<RefreshToken> findByMemberIdAndDeviceId(Long memberId, String deviceId);
}
