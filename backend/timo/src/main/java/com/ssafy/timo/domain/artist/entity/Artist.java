package com.ssafy.timo.domain.artist.entity;

import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

/** 공연을 여는 아티스트. */
@Getter
@Entity
@Table(name = "artist")
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Artist extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "artist_id")
    private Long id;

    @Column(name = "artist_name", length = 200)
    private String name;

    /** 외부 스토리지 URL 이라 길이를 제한하지 않는다. */
    @Column(name = "profile_image", columnDefinition = "TEXT")
    private String profileImage;

    @Builder
    public Artist(String name, String profileImage) {
        this.name = name;
        this.profileImage = profileImage;
    }
}
