package com.ssafy.timo.domain.venue.service;

import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.dto.CommandVenueResponseDto;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.exception.VenueErrorCode;
import com.ssafy.timo.domain.venue.exception.VenueNameDuplicatedException;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.BDDMockito.willThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;

@ExtendWith(MockitoExtension.class)
class VenueServiceImplTest {

    @Mock
    private VenueRepository venueRepository;

    @InjectMocks
    private VenueServiceImpl venueService;

    @Captor
    private ArgumentCaptor<Venue> venueCaptor;

    @Test
    @DisplayName("공연장을 등록하면 저장된 공연장 정보가 응답으로 반환된다")
    void register_success() {
        // given
        CommandVenueRequestDto request = new CommandVenueRequestDto("올림픽공원", "서울시 송파구 올림픽로 424", 5000);
        Venue saved = venue(1L, "올림픽공원", "서울시 송파구 올림픽로 424", 5000);
        given(venueRepository.save(any(Venue.class))).willReturn(saved);

        // when
        CommandVenueResponseDto response = venueService.register(request);

        // then
        assertThat(response.id()).isEqualTo(1L);
        assertThat(response.name()).isEqualTo("올림픽공원");
        assertThat(response.address()).isEqualTo("서울시 송파구 올림픽로 424");
        assertThat(response.totalSeatCount()).isEqualTo(5000);
    }

    @Test
    @DisplayName("공연장을 등록하면 요청 값이 그대로 담긴 엔티티가 저장된다")
    void register_savesVenueBuiltFromRequest() {
        // given
        CommandVenueRequestDto request = new CommandVenueRequestDto("고척돔", "서울시 구로구 경인로 430", 16000);
        given(venueRepository.save(any(Venue.class)))
                .willReturn(venue(1L, "고척돔", "서울시 구로구 경인로 430", 16000));

        // when
        venueService.register(request);

        // then
        then(venueRepository).should(times(1)).save(venueCaptor.capture());

        Venue captured = venueCaptor.getValue();
        assertThat(captured.getId()).isNull();
        assertThat(captured.getName()).isEqualTo("고척돔");
        assertThat(captured.getAddress()).isEqualTo("서울시 구로구 경인로 430");
        assertThat(captured.getTotalSeatCount()).isEqualTo(16000);
    }

    @Test
    @DisplayName("좌석 수가 0인 공연장도 요청 값 그대로 저장된다")
    void register_withZeroSeatCount() {
        // given
        CommandVenueRequestDto request = new CommandVenueRequestDto("소극장", "서울시 종로구 대학로 12", 0);
        given(venueRepository.save(any(Venue.class)))
                .willReturn(venue(1L, "소극장", "서울시 종로구 대학로 12", 0));

        // when
        CommandVenueResponseDto response = venueService.register(request);

        // then
        assertThat(response.totalSeatCount()).isZero();
        then(venueRepository).should().save(venueCaptor.capture());
        assertThat(venueCaptor.getValue().getTotalSeatCount()).isZero();
    }

    @Test
    @DisplayName("저장 중 예외가 발생하면 그대로 전파된다")
    void register_propagatesRepositoryException() {
        // given
        CommandVenueRequestDto request = new CommandVenueRequestDto("올림픽공원", "서울시 송파구 올림픽로 424", 5000);
        willThrow(new IllegalStateException("save failed"))
                .given(venueRepository).save(any(Venue.class));

        // when & then
        assertThatThrownBy(() -> venueService.register(request))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("save failed");
    }

    @Test
    @DisplayName("이미 등록된 공연장명이면 저장하지 않고 중복 예외를 던진다")
    void register_rejectsDuplicatedName() {
        // given
        CommandVenueRequestDto request = new CommandVenueRequestDto("고척돔", "서울시 구로구 경인로 430", 16000);
        given(venueRepository.existsByName("고척돔")).willReturn(true);

        // when & then
        assertThatThrownBy(() -> venueService.register(request))
                .isInstanceOf(VenueNameDuplicatedException.class)
                .hasMessageContaining("고척돔")
                .extracting(e -> ((VenueNameDuplicatedException) e).getErrorCode())
                .isEqualTo(VenueErrorCode.VENUE_NAME_DUPLICATED);

        then(venueRepository).should(never()).save(any(Venue.class));
    }

    @Test
    @DisplayName("같은 이름이 없으면 중복 검사를 통과하고 저장된다")
    void register_passesWhenNameIsNotTaken() {
        // given
        CommandVenueRequestDto request = new CommandVenueRequestDto("고척돔", "서울시 구로구 경인로 430", 16000);
        given(venueRepository.existsByName("고척돔")).willReturn(false);
        given(venueRepository.save(any(Venue.class)))
                .willReturn(venue(1L, "고척돔", "서울시 구로구 경인로 430", 16000));

        // when
        CommandVenueResponseDto response = venueService.register(request);

        // then
        assertThat(response.id()).isEqualTo(1L);
        then(venueRepository).should().existsByName("고척돔");
        then(venueRepository).should().save(any(Venue.class));
    }

    /**
     * Venue 는 식별자를 직접 주입할 수 없으므로, 저장 이후 상태를 재현하기 위해 id 를 리플렉션으로 채운다.
     */
    private Venue venue(Long id, String name, String address, int totalSeatCount) {
        Venue venue = Venue.builder()
                .name(name)
                .address(address)
                .totalSeatCount(totalSeatCount)
                .build();
        ReflectionTestUtils.setField(venue, "id", id);
        return venue;
    }
}
