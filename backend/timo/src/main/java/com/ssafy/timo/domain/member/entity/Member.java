package com.ssafy.timo.domain.member.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Enumerated;
import jakarta.persistence.EnumType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "member")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Member {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role;

    @Column(nullable = false, unique = true, length = 20)
    private String phoneNumber;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MemberStatus status;

    @Column(nullable = false, length = 50)
    private String name;

    @Column(nullable = false, unique = true, length = 30)
    private String nickname;

    @Builder
    private Member(String phoneNumber, String name, String nickname) {
        this.phoneNumber = phoneNumber;
        this.name = name;
        this.nickname = nickname;
        this.role = Role.USER;
        this.status = MemberStatus.ACTIVE;
    }

    public void changeNickname(String nickname) {
        this.nickname = nickname;
    }

    public void withdraw() {
        this.status = MemberStatus.WITHDRAWN;
    }
}
