package com.ssafy.timo.domain.member.entity;

import com.ssafy.timo.domain.auth.exception.MemberSuspendedException;
import com.ssafy.timo.domain.auth.exception.MemberWithdrawnException;
import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 서비스 이용자. 로그인 수단은 {@link com.ssafy.timo.domain.auth.entity.LoginInfo} 가 따로 들고 있다.
 *
 * <p>{@link com.ssafy.timo.global.entity.SoftDeletableEntity} 가 아니라 {@link BaseEntity} 를 상속한다.
 * 탈퇴는 {@link MemberStatus#WITHDRAWN} 으로 표현하므로, 소프트 삭제 플래그까지 두면 "지워졌다" 를
 * 나타내는 장치가 둘이 되어 조회 조건이 갈린다.
 *
 * <p>유니크 제약에 이름을 붙인 이유가 있다. 중복 확인 API 를 통과한 뒤 가입 요청이 도착하기까지
 * 사이에 남이 같은 값을 채갈 수 있어, 최종 판정은 DB 제약 위반으로 이뤄진다. 그때 어느 값이
 * 부딪혔는지(전화번호인지 닉네임인지) 구분해 409 로 내보내려면 예외에 실려 오는 제약 이름이 필요하다.
 */
@Getter
@Entity
@Table(name = "member",
        uniqueConstraints = {
                @UniqueConstraint(name = "uk_member_phone_number", columnNames = "phone_number"),
                @UniqueConstraint(name = "uk_member_nickname", columnNames = "nickname")})
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Member extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "member_id")
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    /** 하이픈 없는 숫자만 저장한다. {@code PhoneNumbers.normalize()} 를 거친 값이어야 한다. */
    @Column(name = "phone_number", nullable = false, length = 20)
    private String phoneNumber;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MemberStatus status;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(nullable = false, length = 30)
    private String nickname;

    @Builder
    private Member(String phoneNumber, String name, String nickname) {
        this.phoneNumber = phoneNumber;
        this.name = name;
        this.nickname = nickname;
        this.role = Role.USER;
        this.status = MemberStatus.ACTIVE;
    }

    /**
     * 서비스를 이용할 수 있는 상태인지 확인한다. 아니면 그 사유대로 예외를 던진다.
     *
     * <p>로그인과 본인 정보 조회가 같은 판정을 써야 해서 엔티티에 둔다. 호출하는 쪽에
     * 각자 {@code switch} 를 두면 {@link MemberStatus} 에 값을 추가할 때 한 곳을 빠뜨리고,
     * 그 상태의 계정이 <b>그냥 통과한다.</b>
     */
    public void verifyActive() {
        switch (status) {
            case ACTIVE -> { }
            case SUSPENDED -> throw new MemberSuspendedException();
            case WITHDRAWN -> throw new MemberWithdrawnException();
        }
    }

    public void changeNickname(String nickname) {
        this.nickname = nickname;
    }

    public void withdraw() {
        this.status = MemberStatus.WITHDRAWN;
    }
}
