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

    /**
     * 본인 정보 조회용. 회원과 로그인 수단을 한 번에 가져온다.
     *
     * <p>{@code LoginInfo} 를 기준으로 찾는 이유는 아이디가 이쪽에 있어서다. 회원부터 찾으면
     * 아이디를 얻으려고 쿼리가 한 번 더 나간다.
     *
     * <p>소셜 로그인이 붙어 아이디·비밀번호 수단이 없는 회원이 생기면 그 회원은 이 조회로
     * 찾히지 않는다. 그때는 {@code Member} 기준으로 바꾸고 아이디를 nullable 로 다뤄야 한다.
     */
    @Query("select l from LoginInfo l join fetch l.member where l.memberId = :memberId")
    Optional<LoginInfo> findByMemberIdWithMember(@Param("memberId") Long memberId);
}
