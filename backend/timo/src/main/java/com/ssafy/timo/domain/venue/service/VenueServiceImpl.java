package com.ssafy.timo.domain.venue.service;

import com.ssafy.timo.domain.venue.dto.CommandVenueRequestDto;
import com.ssafy.timo.domain.venue.dto.CommandVenueResponseDto;
import com.ssafy.timo.domain.venue.entity.Venue;
import com.ssafy.timo.domain.venue.exception.VenueNameDuplicatedException;
import com.ssafy.timo.domain.venue.repository.VenueRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional
public class VenueServiceImpl implements  VenueService{

    private final VenueRepository venueRepository;

    @Override
    public CommandVenueResponseDto register(CommandVenueRequestDto request) {
        // 최종 방어선은 venue_name 의 unique 제약이다. 여기서는 흔한 경우를 409 로 먼저 걸러낸다.
        if (venueRepository.existsByName(request.name())) {
            throw new VenueNameDuplicatedException(request.name());
        }

        Venue venue = Venue.builder()
                .name(request.name())
                .address(request.address())
                .totalSeatCount(request.totalSeatCount())
                .build();

        Venue saved = venueRepository.save(venue);

        return new CommandVenueResponseDto(saved.getId(),
                saved.getName(),
                saved.getAddress(),
                saved.getTotalSeatCount());
    }
}
