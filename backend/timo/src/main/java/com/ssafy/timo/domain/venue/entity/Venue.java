package com.ssafy.timo.domain.venue.entity;


import com.ssafy.timo.global.entity.BaseEntity;
import jakarta.persistence.*;
import lombok.AccessLevel;
import lombok.Builder;
import lombok.Getter;
import lombok.NoArgsConstructor;

@Getter
@Entity
@Table(name = "venue",
        uniqueConstraints = @UniqueConstraint(name = "uk_venue_name", columnNames = "venue_name"))
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class Venue extends BaseEntity {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "venue_id")
    private Long id;

    @Column(name ="venue_name", length = 10)
    private String name;

    @Column(name = "venue_address")
    private String address;

    @Column(name = "total_seat_count")
    private int totalSeatCount;

    @Builder
    public Venue(String name, String address, int totalSeatCount) {
        this.name = name;
        this.address = address;
        this.totalSeatCount = totalSeatCount;
    }
}
