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

    /**
     * 저장소 key. URL 이 아니라 {@link com.ssafy.timo.global.storage.ImageStorage} 가 URL 로 바꾸는
     * key 다({@link com.ssafy.timo.domain.concert.entity.Concert#getPosterImageKey()} 와 같은 취급).
     * 컬럼명은 바꾸지 않는다 - 저장된 값의 shape 만 바뀌었을 뿐 마이그레이션이 필요한 변화는 아니다.
     */
    @Column(name = "profile_image", columnDefinition = "TEXT")
    private String profileImageKey;

    @Builder
    public Artist(String name, String profileImageKey) {
        this.name = name;
        this.profileImageKey = profileImageKey;
    }
}
