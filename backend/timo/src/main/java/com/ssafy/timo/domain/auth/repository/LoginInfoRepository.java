package com.ssafy.timo.domain.auth.repository;

import com.ssafy.timo.domain.auth.entity.LoginInfo;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

@Repository
public interface LoginInfoRepository extends JpaRepository<LoginInfo, Long> {

    /** 아이디 중복 확인. 확인 시점과 가입 시점 사이의 경합은 막지 못하므로 최종 판정은 DB 제약이다. */
    boolean existsByUsername(String username);

    /**
     * 로그인용 조회. 회원을 함께 가져온다.
     *
     * <p>{@code member} 가 {@code LAZY} 라 fetch join 이 없으면 토큰을 만들며
     * {@code getRole()} 을 건드리는 순간 쿼리가 한 번 더 나간다. 로그인은 모든 사용자가
     * 반드시 한 번은 지나는 경로다.
     */
    @Query("select l from LoginInfo l join fetch l.member where l.username = :username")
    Optional<LoginInfo> findByUsernameWithMember(@Param("username") String username);
}
