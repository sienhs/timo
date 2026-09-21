package com.ssafy.timo.domain.concert.controller;

import com.ssafy.timo.domain.concert.dto.ConcertKitResponseDto;
import com.ssafy.timo.domain.concert.entity.ConcertImagePurpose;
import com.ssafy.timo.global.security.CurrentMember;
import java.util.List;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;

/**
 * 소장품 제작용 소재(kit) API 규약.
 *
 * <p>소재는 공연에 붙는 배경·인물 이미지 묶음이고, 앱이 소장품을 만들기 시작할 때 고를 수 있게
 * 서버가 들고 있는 것이다. 사용자가 자기 사진으로 만들 수도 있으므로 소재가 없는 공연도 정상이다 -
 * 그때는 빈 배열이 나간다.
 *
 * <p><b>공연 등록과 분리돼 있다.</b> 소재는 공연을 만든 뒤에 준비되는 경우가 많아 등록을 따로 받는다.
 * 공연 등록({@link ConcertApi})의 요청·응답과 저장 로직은 이것 때문에 바뀌지 않는다.
 */
public interface ConcertKitApi {

    /**
     * 이 공연의 소재. <b>그 공연 티켓을 지금 가진 사람만</b> 볼 수 있다.
     *
     * <p>티켓이 없으면 403 이다. 공연 자체는 인증 없이 열리는 공개 정보라 존재를 숨길 이유가 없어,
     * 굿즈 도메인의 404 규칙과 다르다. 없는 공연은 404.
     *
     * <p>입장 여부는 보지 않는다. 소재는 제작을 시작하기 전에 고르는 것이고, 만들 수 있는지는 굿즈
     * 생성이 {@code USED} 로 따로 가린다.
     */
    @GetMapping("/{concertId}/kit")
    ResponseEntity<ConcertKitResponseDto> findKit(@PathVariable Long concertId,
                                                  @CurrentMember Long memberId);

    /**
     * 소재 이미지를 더한다. 올린 순서가 곧 노출 순서이고 이미 있는 소재 뒤에 붙는다.
     *
     * <p>주최사·운영자용이다. 역할 검사는 {@code SecurityConfig} 가 한다.
     *
     * <p>허용 형식은 jpg·png·webp·gif 이고 그 외에는 400. 없는 공연은 404. 응답은 더한 뒤의 소재
     * 전체다 - 등록 화면이 결과를 바로 그릴 수 있다.
     */
    @PostMapping(value = "/{concertId}/kit/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    ResponseEntity<ConcertKitResponseDto> addKitImages(@PathVariable Long concertId,
                                                       @RequestParam("purpose") ConcertImagePurpose purpose,
                                                       @RequestPart("files") List<MultipartFile> files);
}
