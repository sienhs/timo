package com.ssafy.timo.domain.goods.controller;

import com.ssafy.timo.domain.goods.dto.GoodsImageResponseDto;
import com.ssafy.timo.global.security.CurrentMember;
import java.util.List;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.multipart.MultipartFile;

/**
 * 굿즈 이미지 업로드 API 규약. 생성은 {@link GoodsCreateApi} 에 있다.
 *
 * <p><b>업로드가 생성과 한 요청이 아닌 이유.</b> 이미지는 컬럼 5장뿐 아니라 {@code personLayers}
 * 안에도 들어 있고 그 장수가 레이어·파츠 수에 따라 달라진다. 한 요청으로 받으려면 서버가 파트 이름을
 * JSON 자리로 해석해야 하는데, 그러면 앞으로 바뀔 예정인 앱의 레이어 스키마가 서버 코드에 박힌다.
 * 그래서 이미지는 <b>전부</b> 이 엔드포인트로 올리고, 생성은 key 만 든 JSON 으로 따로 받는다.
 *
 * <p>경로가 티켓 아래인 이유는 {@link GoodsCreateApi} 와 같다. 덤으로 올리기 전에 티켓을 가릴 수 있고,
 * key 접두가 티켓까지 좁혀져 청소 배치가 티켓 단위로 묶을 수 있다.
 */
public interface GoodsImageApi {

    /**
     * 굿즈 이미지 업로드. 여러 장을 한 번에 올리고 <b>올린 순서대로</b> key 와 URL 을 받는다.
     *
     * <p>티켓을 먼저 가리고 저장소에 쓴다 — 거절된 요청은 객체를 하나도 만들지 않는다. 거절 코드는
     * 생성과 같다: 없거나 남의 티켓 404, 입장 전 409. 허용 밖 형식(jpg·png·webp·gif 만)은 400 이다.
     *
     * <p>key 는 서버가 만든다. 앱이 보낸 파일명은 쓰지 않는다.
     *
     * <p>장수 상한은 두지 않는다. 요청 크기는 {@code spring.servlet.multipart} 가 막고, 입장을 마친
     * 자기 티켓을 가진 사람만 올릴 수 있어 남용 경로가 좁다.
     */
    @PostMapping(value = "/{ticketId}/goods/images", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    ResponseEntity<List<GoodsImageResponseDto>> uploadImages(
            @PathVariable Long ticketId,
            @RequestPart("files") List<MultipartFile> files,
            @CurrentMember Long memberId);
}
