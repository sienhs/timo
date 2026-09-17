package com.ssafy.timo.domain.notification.repository;

import com.ssafy.timo.domain.notification.entity.PushDevice;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface PushDeviceRepository extends JpaRepository<PushDevice, Long> {

    Optional<PushDevice> findByToken(String token);

    List<PushDevice> findAllByMember_Id(Long memberId);

    long deleteByTokenAndMember_Id(String token, Long memberId);
}
