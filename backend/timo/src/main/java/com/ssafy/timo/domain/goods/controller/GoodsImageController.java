package com.ssafy.timo.domain.goods.controller;

import com.ssafy.timo.domain.goods.dto.GoodsImageResponseDto;
import com.ssafy.timo.domain.goods.service.GoodsUploadService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * 굿즈 이미지 업로드 API (v1). 매핑과 규약은 {@link GoodsImageApi} 에 있고 여기서는 버전 경로만 정한다.
 *
 * <p>{@link GoodsCreateController} 와 클래스 경로가 같다. 메서드 경로가 다르므로 스프링이 문제 삼지
 * 않고, 둘을 나눈 것은 올리는 일과 만드는 일이 서로 다른 시점에 다른 이유로 바뀌기 때문이다.
 */
@RestController
@RequestMapping("/api/v1/tickets")
@RequiredArgsConstructor
public class GoodsImageController implements GoodsImageApi {

    private final GoodsUploadService goodsUploadService;

    @Override
    public ResponseEntity<List<GoodsImageResponseDto>> uploadImages(Long ticketId,
                                                                    List<MultipartFile> files,
                                                                    Long memberId) {
        List<GoodsImageResponseDto> uploaded = goodsUploadService.upload(memberId, ticketId, files);

        return ResponseEntity.status(HttpStatus.CREATED).body(uploaded);
    }
}
