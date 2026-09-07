package com.ssafy.timo.domain.concert.dto;

import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 공연 생성 요청.
 *
 * <p>상태와 조회수는 서버가 정하므로 받지 않는다. 일정(공연 기간, 예매 오픈)은 선택값이고,
 * 값이 들어온 경우의 선후 관계는 서비스 계층에서 검증한다.
 *
 * <p>이미지는 URL 이 아니라 저장소 key 로 받는다. 파일 자체는 이 API 가 아니라 업로드 경로로 올라가고,
 * 여기에는 이미 올라간 객체의 key 만 넘어온다.
 */
public record CommandConcertRequestDto(

        @NotBlank(message = "공연명은 필수입니다.")
        @Size(max = 200, message = "공연명은 200자 이하여야 합니다.")
        String title,

        @NotNull(message = "공연 장르는 필수입니다.")
        ConcertGenre genre,

        @Size(max = 500, message = "포스터 이미지 key는 500자 이하여야 합니다.")
        String posterImageKey,

        /** 상세 이미지 key 목록. 넘긴 순서가 그대로 노출 순서가 된다. */
        List<@NotBlank(message = "이미지 key는 비어 있을 수 없습니다.")
             @Size(max = 500, message = "이미지 key는 500자 이하여야 합니다.") String> imageKeys,

        String description,

        @NotNull(message = "관람 등급은 필수입니다.")
        AgeRating ageRating,

        LocalDateTime startDate,

        LocalDateTime endDate,

        LocalDateTime openAt,

        @NotNull(message = "공연장 ID는 필수입니다.")
        Long venueId,

        @NotEmpty(message = "출연 아티스트는 최소 1명이어야 합니다.")
        List<@NotNull(message = "아티스트 ID는 비어 있을 수 없습니다.") Long> artistIds
) {

    /** 넘어오지 않은 이미지 목록은 빈 목록으로 다룬다. */
    public List<String> imageKeysOrEmpty() {
        return imageKeys == null ? List.of() : imageKeys;
    }
}
