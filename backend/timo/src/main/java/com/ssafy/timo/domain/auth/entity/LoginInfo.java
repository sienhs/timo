package com.ssafy.timo.domain.auth.entity;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.MapsId;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 아이디·비밀번호 로그인 수단. {@link Member} 와 1:1 이고 회원 식별자를 PK 로 공유한다.
 *
 * <p>회원 정보와 한 테이블에 두지 않은 이유는 노출 범위가 다르기 때문이다. 닉네임·이름은 조회되지만
 * 비밀번호 해시는 로그인·비밀번호 변경 때만 읽힌다. 나중에 소셜 로그인이 붙어도 회원 테이블은
 * 그대로 두고 이 옆에 수단을 하나 더 놓으면 된다.
 *
 * <p>{@link BaseEntity} 를 상속해 {@code updated_at} 이 남는다. 비밀번호가 마지막으로 바뀐 시각을
 * 따로 관리하지 않아도 되고, 계정 도용 조사 때 단서가 된다.
 */
@Getter
@Entity
@Table(name = "login_info",
        uniqueConstraints = @UniqueConstraint(name = "uk_login_info_username", columnNames = "username"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class LoginInfo extends BaseEntity {

    /** PK 이자 FK. 값은 {@link MapsId} 가 {@link #member} 에서 가져와 채운다. */
    @Id
    @Column(name = "member_id")
    private Long memberId;

    @MapsId
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    private Member member;

    @Column(nullable = false, length = 50)
    private String username;

    /** BCrypt 해시. 평문은 어디에도 남기지 않는다. */
    @Column(name = "password_hash", nullable = false, length = 255)
    private String passwordHash;

    @Builder
    private LoginInfo(Member member, String username, String passwordHash) {
        this.member = member;
        this.username = username;
        this.passwordHash = passwordHash;
    }

    public void changePassword(String passwordHash) {
        this.passwordHash = passwordHash;
    }
}
