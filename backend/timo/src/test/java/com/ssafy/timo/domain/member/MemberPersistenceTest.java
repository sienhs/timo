package com.ssafy.timo.domain.member;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.catchThrowableOfType;

import com.ssafy.timo.domain.auth.entity.LoginInfo;
import com.ssafy.timo.domain.auth.repository.LoginInfoRepository;
import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.domain.member.entity.MemberStatus;
import com.ssafy.timo.domain.member.entity.Role;
import com.ssafy.timo.domain.member.repository.MemberRepository;
import com.ssafy.timo.support.IntegrationTest;
import jakarta.persistence.EntityManager;
import org.hibernate.exception.ConstraintViolationException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.dao.DataIntegrityViolationException;

/**
 * 회원·로그인 수단의 저장 동작을 실제 MySQL 로 확인한다.
 *
 * <p>중복 판정을 특히 신경 써서 본다. 중복 확인 API 를 통과한 뒤 가입 요청이 도착하기까지
 * 사이에 남이 같은 값을 채갈 수 있어, 최종 판정은 DB 유니크 제약이 한다. 가입 API 가 그 위반을
 * 409 로 바꾸려면 <b>어느 제약이 깨졌는지</b> 를 예외에서 읽어낼 수 있어야 하는데,
 * 그게 실제로 되는지 여기서 못 박는다. 안 되면 "닉네임이 중복입니다" 를 전화번호 중복에도
 * 내보내게 된다.
 */
@IntegrationTest
class MemberPersistenceTest {

    private static final String PHONE = "01012345678";
    private static final String NICKNAME = "티모";
    private static final String USERNAME = "timo_user";

    @Autowired
    private MemberRepository memberRepository;

    @Autowired
    private LoginInfoRepository loginInfoRepository;

    @Autowired
    private EntityManager em;

    @Test
    @DisplayName("저장하면 기본 권한·상태가 채워지고 생성·수정 시각이 남는다")
    void save_fillsDefaultsAndAuditFields() {
        Member member = memberRepository.save(member(PHONE, NICKNAME));

        assertThat(member.getId()).isNotNull();
        assertThat(member.getRole()).isEqualTo(Role.USER);
        assertThat(member.getStatus()).isEqualTo(MemberStatus.ACTIVE);
        assertThat(member.getCreatedAt()).isNotNull();
        assertThat(member.getUpdatedAt()).isNotNull();
    }

    @Test
    @DisplayName("로그인 수단은 회원 식별자를 PK 로 공유한다")
    void loginInfo_sharesMemberId() {
        Member member = memberRepository.save(member(PHONE, NICKNAME));

        LoginInfo loginInfo = loginInfoRepository.save(LoginInfo.builder()
                .member(member)
                .username(USERNAME)
                .passwordHash("$2a$10$dummyhashdummyhashdummyhashdummyhash")
                .build());

        assertThat(loginInfo.getMemberId()).isEqualTo(member.getId());
        assertThat(loginInfo.getCreatedAt()).isNotNull();
    }

    @Test
    @DisplayName("중복 확인은 저장된 값을 찾아낸다")
    void existsQueries_findStoredValues() {
        Member member = memberRepository.save(member(PHONE, NICKNAME));
        loginInfoRepository.save(LoginInfo.builder()
                .member(member)
                .username(USERNAME)
                .passwordHash("$2a$10$dummyhashdummyhashdummyhashdummyhash")
                .build());
        em.flush();

        assertThat(memberRepository.existsByNickname(NICKNAME)).isTrue();
        assertThat(memberRepository.existsByPhoneNumber(PHONE)).isTrue();
        assertThat(loginInfoRepository.existsByUsername(USERNAME)).isTrue();

        assertThat(memberRepository.existsByNickname("다른닉네임")).isFalse();
        assertThat(memberRepository.existsByPhoneNumber("01099998888")).isFalse();
        assertThat(loginInfoRepository.existsByUsername("other_user")).isFalse();
    }

    @Test
    @DisplayName("닉네임이 겹치면 어느 제약이 깨졌는지 알 수 있다")
    void duplicateNickname_reportsConstraintName() {
        memberRepository.save(member(PHONE, NICKNAME));

        assertThat(violatedConstraintOf(() -> memberRepository.save(member("01099998888", NICKNAME))))
                .isEqualTo("uk_member_nickname");
    }

    @Test
    @DisplayName("전화번호가 겹치면 어느 제약이 깨졌는지 알 수 있다")
    void duplicatePhoneNumber_reportsConstraintName() {
        memberRepository.save(member(PHONE, NICKNAME));

        assertThat(violatedConstraintOf(() -> memberRepository.save(member(PHONE, "다른닉네임"))))
                .isEqualTo("uk_member_phone_number");
    }

    @Test
    @DisplayName("아이디가 겹치면 어느 제약이 깨졌는지 알 수 있다")
    void duplicateUsername_reportsConstraintName() {
        Member first = memberRepository.save(member(PHONE, NICKNAME));
        Member second = memberRepository.save(member("01099998888", "다른닉네임"));
        loginInfoRepository.saveAndFlush(loginInfo(first, USERNAME));

        assertThat(violatedConstraintOf(() -> loginInfoRepository.saveAndFlush(loginInfo(second, USERNAME))))
                .isEqualTo("uk_login_info_username");
    }

    /**
     * 저장을 터뜨리고, 위반된 유니크 제약의 이름을 꺼낸다.
     *
     * <p>예외 타입이 상황에 따라 다르다. {@link Member} 는 IDENTITY 라 {@code save()} 가 곧바로
     * INSERT 를 날리고 스프링이 {@link DataIntegrityViolationException} 으로 바꿔 주지만,
     * {@link LoginInfo} 는 {@code @MapsId} 로 식별자가 이미 정해져 있어 INSERT 가 flush 까지 밀린다.
     * 그래서 타입을 가리지 않고 원인 사슬에서 하이버네이트 예외를 찾는다.
     *
     * <p>MySQL 이 돌려주는 제약 이름에는 {@code member.uk_member_nickname} 처럼 테이블명이 앞에 붙는다.
     * 가입 API 도 같은 방식으로 잘라 써야 한다.
     */
    private String violatedConstraintOf(Runnable save) {
        Exception exception = catchThrowableOfType(Exception.class, save::run);
        assertThat(exception).as("중복인데 저장이 통과했다").isNotNull();

        for (Throwable cause = exception; cause != null; cause = cause.getCause()) {
            if (cause instanceof ConstraintViolationException violation) {
                String name = violation.getConstraintName();
                return name == null ? null : name.substring(name.lastIndexOf('.') + 1);
            }
        }
        throw new AssertionError("ConstraintViolationException 을 찾지 못했다: " + exception);
    }

    private Member member(String phoneNumber, String nickname) {
        return Member.builder()
                .phoneNumber(phoneNumber)
                .name("정희성")
                .nickname(nickname)
                .build();
    }

    private LoginInfo loginInfo(Member member, String username) {
        return LoginInfo.builder()
                .member(member)
                .username(username)
                .passwordHash("$2a$10$dummyhashdummyhashdummyhashdummyhash")
                .build();
    }
}
