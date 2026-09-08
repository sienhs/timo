package com.ssafy.timo.domain.auth.repository;

import com.ssafy.timo.domain.auth.entity.LoginInfo;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface LoginInfoRepository extends JpaRepository<LoginInfo, Long> {

    /** 아이디 중복 확인. 확인 시점과 가입 시점 사이의 경합은 막지 못하므로 최종 판정은 DB 제약이다. */
    boolean existsByUsername(String username);
}
