package com.ssafy.timo.domain.concert.dto;

import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertImage;
import com.ssafy.timo.domain.concert.entity.ConcertImagePurpose;
import com.ssafy.timo.global.storage.ImageStorage;
import java.util.List;

/**
 * 소장품 제작용 소재 묶음. 그 공연 티켓을 지금 가진 사람에게만 나간다.
 *
 * <p><b>영상은 없다.</b> 공연에 영상 컬럼이 없고 저장소도 이미지 형식만 받는다. 앱 초안의
 * {@code video} 자리는 이 응답에 두지 않는다 - 늘 {@code null} 인 필드를 내려보내는 것보다 없는
 * 편이 낫다.
 *
 * <p>{@code width}·{@code height}·{@code label} 도 없다. 서버는 이미지를 열어 보지 않으므로 그 값을
 * 알 방법이 없고, 지금 저장하는 것은 key 와 순서뿐이다. 필요해지면 등록할 때 함께 받아야 한다.
 *
 * @param backgrounds 배경 소재, {@code sortOrder} 순
 * @param people      인물 소재, {@code sortOrder} 순
 */
public record ConcertKitResponseDto(Long concertId,
                                    List<AssetDto> backgrounds,
                                    List<AssetDto> people) {

    /**
     * 소재 한 장.
     *
     * @param assetId      서버가 가진 이미지 식별자
     * @param thumbnailUrl 원본과 같은 URL 이다 - 서버는 이미지를 가공하지 않아 축소본을 만들지 않는다
     */
    public record AssetDto(Long assetId, String url, String thumbnailUrl, int sortOrder) {

        static AssetDto from(ConcertImage image, ImageStorage imageStorage) {
            String url = imageStorage.getUrl(image.getImageKey());

            return new AssetDto(image.getId(), url, url, image.getSortOrder());
        }
    }

    public static ConcertKitResponseDto from(Concert concert, ImageStorage imageStorage) {
        return new ConcertKitResponseDto(
                concert.getId(),
                assets(concert, ConcertImagePurpose.KIT_BACKGROUND, imageStorage),
                assets(concert, ConcertImagePurpose.KIT_PERSON, imageStorage));
    }

    private static List<AssetDto> assets(Concert concert,
                                         ConcertImagePurpose purpose,
                                         ImageStorage imageStorage) {
        return concert.getKitImages(purpose).stream()
                .map(image -> AssetDto.from(image, imageStorage))
                .toList();
    }
}
