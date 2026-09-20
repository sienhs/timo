package com.ssafy.timo.domain.notification.repository;

import com.ssafy.timo.domain.notification.dto.PushTokenRow;
import com.ssafy.timo.domain.notification.entity.PushDevice;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface PushDeviceRepository extends JpaRepository<PushDevice, Long> {

    Optional<PushDevice> findByToken(String token);

    List<PushDevice> findAllByMember_Id(Long memberId);

    long deleteByTokenAndMember_Id(String token, Long memberId);

    /** 여러 회원의 토큰을 한 번에. 어느 회원의 토큰인지 함께 돌려준다. */
    @Query("select d.member.id as memberId, d.token as token from PushDevice d where d.member.id in :memberIds")
    List<PushTokenRow> findTokenRowsByMemberIdIn(@Param("memberIds") Collection<Long> memberIds);

    /**
     * 더는 쓸 수 없는 토큰을 지운다. FCM 이 죽었다고 알려 준 토큰이라 회원과 무관하게 지운다.
     * 이미 없는 토큰이 섞여 있어도 예외가 아니다.
     */
    @Modifying
    @Query("delete from PushDevice d where d.token in :tokens")
    int deleteAllByTokenIn(@Param("tokens") Collection<String> tokens);
}
