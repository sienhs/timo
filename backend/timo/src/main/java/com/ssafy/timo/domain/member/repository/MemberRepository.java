package com.ssafy.timo.domain.member.repository;

import com.ssafy.timo.domain.member.entity.Member;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface MemberRepository extends JpaRepository<Member, Long> {

    /** 닉네임 중복 확인. 확인 시점과 가입 시점 사이의 경합은 막지 못하므로 최종 판정은 DB 제약이다. */
    boolean existsByNickname(String nickname);

    /** 이미 가입된 번호인지. 정규화된(숫자만) 번호로 물어야 한다. */
    boolean existsByPhoneNumber(String phoneNumber);
}
