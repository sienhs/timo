package com.ssafy.timo.domain.notification.entity;

import com.ssafy.timo.domain.member.entity.Member;
import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** 회원의 앱 설치본 하나가 가진 FCM 등록 토큰. 토큰은 기기 초기화·앱 재설치 때 바뀔 수 있다. */
@Getter
@Entity
@Table(name = "push_device", uniqueConstraints =
        @UniqueConstraint(name = "uk_push_device_token", columnNames = "token"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class PushDevice extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "push_device_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "member_id", nullable = false)
    private Member member;

    @Column(nullable = false, length = 512)
    private String token;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PushPlatform platform;

    @Builder
    private PushDevice(Member member, String token, PushPlatform platform) {
        this.member = member;
        this.token = token;
        this.platform = platform;
    }

    /** 같은 설치본이 다른 계정으로 로그인할 수 있으므로 마지막 로그인 회원으로 갱신한다. */
    public void refresh(Member member, PushPlatform platform) {
        this.member = member;
        this.platform = platform;
    }
}
