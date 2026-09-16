package com.ssafy.timo.domain.reservation.service;

import com.ssafy.timo.domain.reservation.dto.CreateReservationRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationDetailResponseDto;
import com.ssafy.timo.domain.reservation.dto.ReservationListRequestDto;
import com.ssafy.timo.domain.reservation.dto.ReservationSummaryResponseDto;
import org.springframework.data.web.PagedModel;

public interface ReservationService {

    ReservationDetailResponseDto create(CreateReservationRequestDto request);

    PagedModel<ReservationSummaryResponseDto> findAll(ReservationListRequestDto request);

    ReservationDetailResponseDto find(Long reservationId);

    ReservationDetailResponseDto cancel(Long reservationId);
}
