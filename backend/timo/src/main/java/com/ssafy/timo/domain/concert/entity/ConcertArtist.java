package com.ssafy.timo.domain.concert.entity;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import lombok.AccessLevel;
import lombok.Getter;
import lombok.NoArgsConstructor;

/**
 * 공연에 출연하는 아티스트. 공연과 아티스트의 다대다를 잇는다.
 *
 * <p>{@code @ManyToMany} 대신 엔티티로 둔 이유는 두 가지다. 출연 순서나 역할(헤드라이너/게스트) 같은
 * 컬럼이 나중에 붙을 자리가 필요하고, {@code @ManyToMany} 는 목록을 수정할 때 기존 행을 모두 지우고
 * 다시 넣는 쿼리를 만들기 때문이다.
 *
 * <p>생성은 {@link Concert#addArtist(Artist)} 를 통해서만 한다.
 */
@Getter
@Entity
@Table(name = "concert_artist",
        uniqueConstraints = @UniqueConstraint(
                name = "uk_concert_artist",
                columnNames = {"concert_id", "artist_id"}))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class ConcertArtist extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "concert_artist_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "concert_id", nullable = false)
    private Concert concert;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "artist_id", nullable = false)
    private Artist artist;

    ConcertArtist(Concert concert, Artist artist) {
        this.concert = concert;
        this.artist = artist;
    }
}
