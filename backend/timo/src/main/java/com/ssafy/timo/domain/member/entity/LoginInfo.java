package com.ssafy.timo.domain.member.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.MapsId;
import jakarta.persistence.OneToOne;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "login_info")
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class LoginInfo {

    @Id
    private Long memberId;          // PK이자 FK

    @MapsId
    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "member_id")
    private Member member;

    @Column(nullable = false, unique = true, length = 50)
    private String username;

    @Column(nullable = false, length = 60)
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
