package com.ssafy.timo.domain.concert.controller;

import com.ssafy.timo.domain.concert.dto.CommandConcertRequestDto;
import com.ssafy.timo.domain.concert.dto.CommandConcertResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertDetailResponseDto;
import com.ssafy.timo.domain.concert.dto.ConcertListRequestDto;
import com.ssafy.timo.domain.concert.dto.ConcertSummaryResponseDto;
import com.ssafy.timo.domain.concert.service.ConcertService;
import com.ssafy.timo.global.storage.ImageStorage;
import lombok.RequiredArgsConstructor;
import org.springframework.data.web.PagedModel;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.net.URI;
import java.util.List;
import java.util.UUID;

/**
 * 공연 API (v1, 실제 구현).
 *
 * <p>엔드포인트 매핑과 검증 규약은 {@link ConcertApi} 에 있다. 이 클래스는 버전 경로를 정하고
 * 서비스에 위임만 한다. 프론트 연동용 스텁은 {@code /api/v0/concerts} 에 같은 규약으로 떠 있다.
 *
 * <p>요청 검증 실패는 {@link com.ssafy.timo.global.exception.GlobalExceptionHandler} 가
 * Problem Details 로 변환하므로 여기서 따로 처리하지 않는다.
 */
@RestController
@RequestMapping(ConcertController.BASE_PATH)
@RequiredArgsConstructor
public class ConcertController implements ConcertApi {

    /** Location 헤더를 만들 때도 재사용하도록 상수로 둔다. */
    static final String BASE_PATH = "/api/v1/concerts";

    private final ConcertService concertService;
    private final ImageStorage imageStorage;

    @Override
    public ResponseEntity<CommandConcertResponseDto> create(CommandConcertRequestDto request,
                                                              MultipartFile poster,
                                                              List<MultipartFile> images) {
        CommandConcertResponseDto response = concertService.create(withUploadedImages(request, poster, images));

        return ResponseEntity
                .created(URI.create(BASE_PATH + "/" + response.id()))
                .body(response);
    }

    /**
     * 포스터·상세 이미지를 업로드해 key 를 채운 요청을 만든다. 공연은 아직 저장 전이라 DB id 가 없으니,
     * key 를 묶는 폴더명은 DB id 대신 무작위 값을 쓴다 - S3 경로가 DB id 와 맞아떨어질 필요는 없다.
     *
     * <p>v0 스텁({@link com.ssafy.timo.stub.concert.ConcertStubController})에도 같은 메서드가 있다 -
     * 스텁은 이 컨트롤러에 의존하지 않는 별개 구현이라({@link ConcertApi} 참고) 옮겨 쓸 수 없다.
     */
    private CommandConcertRequestDto withUploadedImages(CommandConcertRequestDto request,
                                                          MultipartFile poster,
                                                          List<MultipartFile> images) {
        String groupId = UUID.randomUUID().toString();
        String posterKey = poster == null || poster.isEmpty()
                ? null
                : imageStorage.upload("concert/" + groupId + "/poster", poster);
        List<String> imageKeys = images == null
                ? List.of()
                : images.stream()
                        .filter(image -> !image.isEmpty())
                        .map(image -> imageStorage.upload("concert/" + groupId + "/detail", image))
                        .toList();

        return request.withImages(posterKey, imageKeys);
    }

    @Override
    public ResponseEntity<PagedModel<ConcertSummaryResponseDto>> findAll(ConcertListRequestDto request) {
        return ResponseEntity.ok(concertService.findAll(request));
    }

    @Override
    public ResponseEntity<ConcertDetailResponseDto> find(Long concertId) {
        return ResponseEntity.ok(concertService.find(concertId));
    }
}
