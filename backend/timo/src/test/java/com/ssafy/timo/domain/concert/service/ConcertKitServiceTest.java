package com.ssafy.timo.domain.concert.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.ssafy.timo.domain.concert.dto.ConcertKitResponseDto;
import com.ssafy.timo.domain.concert.entity.AgeRating;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertGenre;
import com.ssafy.timo.domain.concert.entity.ConcertImagePurpose;
import com.ssafy.timo.domain.concert.exception.ConcertKitForbiddenException;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.global.storage.ImageStorage;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

/**
 * 소재는 <b>그 공연 티켓을 지금 가진 사람만</b> 본다는 것과, 소재를 더해도 상세 이미지가 밀리지
 * 않는다는 것을 본다. 뒤쪽이 중요한 이유는 둘이 같은 표에 살기 때문이다.
 */
@ExtendWith(MockitoExtension.class)
class ConcertKitServiceTest {

    private static final long MEMBER_ID = 7L;
    private static final long CONCERT_ID = 1024L;

    @Mock
    private ConcertRepository concertRepository;

    @Mock
    private ImageStorage imageStorage;

    private ConcertKitService service;
    private Concert concert;

    @BeforeEach
    void setUp() {
        service = new ConcertKitService(concertRepository, imageStorage);
        concert = Concert.builder()
                .title("아이유 콘서트")
                .genre(ConcertGenre.CONCERT)
                .ageRating(AgeRating.ALL)
                .posterImageKey("poster.jpg")
                .startDate(LocalDateTime.of(2026, 9, 26, 19, 0))
                .venue(Venue.builder().name("고척돔").address("서울").totalSeatCount(100).build())
                .build();
    }

    @Test
    @DisplayName("티켓을 가진 사람에게는 배경과 인물이 올린 순서대로 나간다")
    void returnsKitToTicketHolder() {
        concert.addKitImage("concert/1024/kit/bg1.png", ConcertImagePurpose.KIT_BACKGROUND);
        concert.addKitImage("concert/1024/kit/bg2.png", ConcertImagePurpose.KIT_BACKGROUND);
        concert.addKitImage("concert/1024/kit/p1.png", ConcertImagePurpose.KIT_PERSON);
        givenTicketHolder();
        givenCdnUrls();

        ConcertKitResponseDto kit = service.findKit(MEMBER_ID, CONCERT_ID);

        assertThat(kit.backgrounds()).hasSize(2)
                .extracting(ConcertKitResponseDto.AssetDto::sortOrder).containsExactly(0, 1);
        assertThat(kit.backgrounds().getFirst().url()).isEqualTo("https://cdn/concert/1024/kit/bg1.png");
        assertThat(kit.people()).hasSize(1);
        // 서버는 이미지를 가공하지 않아 축소본이 없다. 썸네일은 원본과 같은 URL 이다.
        assertThat(kit.people().getFirst().thumbnailUrl()).isEqualTo(kit.people().getFirst().url());
    }

    @Test
    @DisplayName("소재가 없는 공연이어도 정상이다 - 빈 배열이 나간다")
    void returnsEmptyKit() {
        givenTicketHolder();

        ConcertKitResponseDto kit = service.findKit(MEMBER_ID, CONCERT_ID);

        assertThat(kit.backgrounds()).isEmpty();
        assertThat(kit.people()).isEmpty();
    }

    @Test
    @DisplayName("그 공연 티켓이 없으면 403 - 공연은 공개라 존재를 숨기지 않는다")
    void rejectsNonHolder() {
        given(concertRepository.findById(CONCERT_ID)).willReturn(Optional.of(concert));
        given(concertRepository.countCurrentOwnershipOfConcert(MEMBER_ID, CONCERT_ID)).willReturn(0L);

        assertThatThrownBy(() -> service.findKit(MEMBER_ID, CONCERT_ID))
                .isInstanceOf(ConcertKitForbiddenException.class);
    }

    @Test
    @DisplayName("없는 공연은 404")
    void rejectsMissingConcert() {
        given(concertRepository.findById(CONCERT_ID)).willReturn(Optional.empty());

        assertThatThrownBy(() -> service.findKit(MEMBER_ID, CONCERT_ID))
                .isInstanceOf(ConcertNotFoundException.class);
    }

    @Test
    @DisplayName("소재를 더해도 상세 이미지는 그대로다 - 순서를 용도마다 따로 센다")
    void keepsDetailImagesUntouched() {
        concert.addImage("concert/1024/detail1.png");
        concert.addImage("concert/1024/detail2.png");
        given(concertRepository.findById(CONCERT_ID)).willReturn(Optional.of(concert));
        given(imageStorage.upload(anyString(), any(MultipartFile.class))).willReturn("concert/1024/kit/bg.png");
        givenCdnUrls();

        ConcertKitResponseDto kit = service.addImages(CONCERT_ID, ConcertImagePurpose.KIT_BACKGROUND,
                List.of(image("bg.png")));

        assertThat(kit.backgrounds()).hasSize(1);
        assertThat(kit.backgrounds().getFirst().sortOrder()).isZero();
        assertThat(concert.getImages())
                .extracting(image -> image.getImageKey())
                .containsExactly("concert/1024/detail1.png", "concert/1024/detail2.png");
    }

    @Test
    @DisplayName("빈 파트는 건너뛴다")
    void skipsEmptyParts() {
        given(concertRepository.findById(CONCERT_ID)).willReturn(Optional.of(concert));

        ConcertKitResponseDto kit = service.addImages(CONCERT_ID, ConcertImagePurpose.KIT_PERSON,
                List.of(new MockMultipartFile("files", "empty.png", "image/png", new byte[0])));

        assertThat(kit.people()).isEmpty();
        verify(imageStorage, never()).upload(anyString(), any(MultipartFile.class));
    }

    private void givenTicketHolder() {
        given(concertRepository.findById(CONCERT_ID)).willReturn(Optional.of(concert));
        given(concertRepository.countCurrentOwnershipOfConcert(MEMBER_ID, CONCERT_ID)).willReturn(1L);
    }

    /** 소재가 없는 경우에는 불리지 않으므로 쓰는 테스트에서만 건다(엄격 스텁). */
    private void givenCdnUrls() {
        given(imageStorage.getUrl(anyString())).willAnswer(inv -> "https://cdn/" + inv.getArgument(0));
    }

    private MultipartFile image(String name) {
        return new MockMultipartFile("files", name, "image/png", new byte[]{1, 2, 3});
    }
}
