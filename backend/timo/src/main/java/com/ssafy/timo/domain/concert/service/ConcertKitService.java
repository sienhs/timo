package com.ssafy.timo.domain.concert.service;

import com.ssafy.timo.domain.concert.dto.ConcertKitResponseDto;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.concert.entity.ConcertImagePurpose;
import com.ssafy.timo.domain.concert.exception.ConcertKitForbiddenException;
import com.ssafy.timo.domain.concert.exception.ConcertNotFoundException;
import com.ssafy.timo.domain.concert.repository.ConcertRepository;
import com.ssafy.timo.global.storage.ImageStorage;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * 소장품 제작용 소재(kit). 주최사·운영자가 공연마다 올려 두고, 그 공연 티켓을 가진 사람이 받아 간다.
 *
 * <p><b>공연 등록 경로는 건드리지 않는다.</b> 소재는 공연을 만든 뒤에 준비되는 경우가 많아 등록을
 * 따로 받는다. {@code ConcertService.create} 와 그 응답은 그대로이고, 소재는 {@code purpose} 로만
 * 갈리므로 공연 상세 응답에도 섞이지 않는다({@link Concert#getImages()} 참고).
 *
 * <p>읽기는 티켓 보유자에게만 연다. 입장 여부는 보지 않는다 - 소재는 제작을 시작하기 전에 고르는
 * 것이고, 만들 수 있는지는 굿즈 쪽이 {@code USED} 로 따로 가린다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ConcertKitService {

    private final ConcertRepository concertRepository;
    private final ImageStorage imageStorage;

    /**
     * 이 공연의 소재를 돌려준다.
     *
     * @throws ConcertNotFoundException     없는 공연이면 (404)
     * @throws ConcertKitForbiddenException 그 공연 티켓을 지금 가지고 있지 않으면 (403)
     */
    @Transactional(readOnly = true)
    public ConcertKitResponseDto findKit(Long memberId, Long concertId) {
        Concert concert = concertRepository.findById(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));

        if (concertRepository.countCurrentOwnershipOfConcert(memberId, concertId) == 0) {
            // 공연 자체는 공개라 존재를 숨길 이유가 없다. 자격이 없다는 뜻의 403 이다.
            log.debug("소재 조회 거절 - 티켓 미보유 (memberId={}, concertId={})", memberId, concertId);
            throw new ConcertKitForbiddenException();
        }

        return ConcertKitResponseDto.from(concert, imageStorage);
    }

    /**
     * 소재 이미지를 더한다. 올린 순서가 곧 노출 순서이고, 이미 있는 소재 뒤에 붙는다.
     *
     * <p>누가 부를 수 있는지는 {@code SecurityConfig} 가 역할로 가린다 - 서비스는 공연 존재만 본다.
     *
     * @param purpose 배경({@code KIT_BACKGROUND}) 또는 인물({@code KIT_PERSON})
     * @throws ConcertNotFoundException 없는 공연이면 (404)
     */
    @Transactional
    public ConcertKitResponseDto addImages(Long concertId,
                                           ConcertImagePurpose purpose,
                                           List<MultipartFile> files) {
        Concert concert = concertRepository.findById(concertId)
                .orElseThrow(() -> new ConcertNotFoundException(concertId));

        int added = 0;
        for (MultipartFile file : files) {
            if (file == null || file.isEmpty()) {
                continue;
            }
            concert.addKitImage(imageStorage.upload("concert/" + concertId + "/kit", file), purpose);
            added++;
        }

        // 응답에 실을 assetId 는 INSERT 가 나가야 정해진다. flush 없이 만들면 방금 올린 소재의
        // id 가 전부 null 로 나가 등록 화면이 그것을 가리킬 수 없다.
        concertRepository.flush();

        log.info("공연 소재 등록 (concertId={}, purpose={}, count={})", concertId, purpose, added);
        return ConcertKitResponseDto.from(concert, imageStorage);
    }
}
