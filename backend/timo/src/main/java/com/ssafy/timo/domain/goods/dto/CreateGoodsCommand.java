package com.ssafy.timo.domain.goods.dto;

import com.ssafy.timo.domain.goods.entity.GoodsEffect;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import tools.jackson.databind.JsonNode;

/**
 * 굿즈 생성 요청. 이미지는 AI 서버가 S3 에 올리고 앱에 key 를 돌려준 뒤라, <b>key 가 정해진 뒤</b>의 값이다.
 * 서버는 파일을 받지 않는다.
 *
 * <p>{@code memberId}·{@code concertId}·{@code concertSnapshot} 은 없다. 요청자는 토큰에서, 공연은
 * 티켓에서 서버가 정한다. 클라이언트가 보낸 값을 신원이나 소속으로 쓰지 않는다.
 *
 * <p>JSON 필드는 {@link JsonNode} 로 받아 구조를 해석하지 않고 그대로 저장한다. 단
 * {@code personLayers} 는 배열 길이와 {@code layerOrder} 중복만 본다({@code GoodsService}).
 *
 * <p>컨트롤러가 붙으면 이 레코드가 그대로 {@code @Valid @RequestBody} 다. 검증 애노테이션은 그때 쓰인다.
 */
public record CreateGoodsCommand(

        @NotBlank(message = "clientGoodsId 는 필수입니다.")
        @Size(max = 64, message = "clientGoodsId 는 64자 이하여야 합니다.")
        String clientGoodsId,

        @NotBlank(message = "backgroundKey 는 필수입니다.")
        @Size(max = 512)
        String backgroundKey,

        @Size(max = 512)
        String sourceBackgroundKey,

        @Size(max = 512)
        String personCompositeKey,

        @Size(max = 512)
        String depthMapKey,

        @Size(max = 512)
        String previewKey,

        @NotNull(message = "effectType 은 필수입니다.")
        GoodsEffect effectType,

        JsonNode backgroundFraming,

        @NotNull(message = "personLayers 는 필수입니다.")
        JsonNode personLayers,

        @NotNull(message = "transitionConfig 는 필수입니다.")
        JsonNode transitionConfig,

        @NotNull(message = "renderMetadata 는 필수입니다.")
        JsonNode renderMetadata
) {
}
