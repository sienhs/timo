package com.ssafy.timo.domain.goods.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.ssafy.timo.domain.goods.exception.GoodsInvalidLayersException;
import com.ssafy.timo.global.storage.PlaceholderImageStorage;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * JSON 컬럼 규칙 — {@code personLayers} 검증과 상세 응답의 URL 주입.
 *
 * <p>서버가 구조를 해석하지 않는다는 규칙의 경계를 여기서 못 박는다: 검증은 길이와 순서뿐이고,
 * URL 주입은 key 가 문자열일 때만이며 나머지는 손대지 않는다.
 */
class GoodsJsonTest {

    private final JsonMapper mapper = JsonMapper.builder().build();
    private final GoodsJson goodsJson = new GoodsJson(mapper);
    private final PlaceholderImageStorage imageStorage = new PlaceholderImageStorage("https://cdn.example");

    @Test
    @DisplayName("레이어 2개, layerOrder 가 다르면 통과한다")
    void twoLayersDistinctOrder() {
        JsonNode layers = mapper.readTree("""
                [{"cutoutKey":"a","layerOrder":0},{"cutoutKey":"b","layerOrder":1}]
                """);

        assertThatCode(() -> goodsJson.validatePersonLayers(layers)).doesNotThrowAnyException();
    }

    @Test
    @DisplayName("빈 배열도 통과한다 - 인물 없는 굿즈")
    void emptyArray() {
        assertThatCode(() -> goodsJson.validatePersonLayers(mapper.readTree("[]")))
                .doesNotThrowAnyException();
    }

    @Test
    @DisplayName("레이어가 3개면 400")
    void threeLayers() {
        JsonNode layers = mapper.readTree("""
                [{"layerOrder":0},{"layerOrder":1},{"layerOrder":2}]
                """);

        assertThatThrownBy(() -> goodsJson.validatePersonLayers(layers))
                .isInstanceOf(GoodsInvalidLayersException.class);
    }

    @Test
    @DisplayName("layerOrder 가 겹치면 400")
    void duplicateOrder() {
        JsonNode layers = mapper.readTree("""
                [{"layerOrder":1},{"layerOrder":1}]
                """);

        assertThatThrownBy(() -> goodsJson.validatePersonLayers(layers))
                .isInstanceOf(GoodsInvalidLayersException.class);
    }

    @Test
    @DisplayName("둘 다 layerOrder 가 없으면 겹친 것이다 - 위아래를 정할 수 없다")
    void bothMissingOrder() {
        JsonNode layers = mapper.readTree("""
                [{"cutoutKey":"a"},{"cutoutKey":"b"}]
                """);

        assertThatThrownBy(() -> goodsJson.validatePersonLayers(layers))
                .isInstanceOf(GoodsInvalidLayersException.class);
    }

    @Test
    @DisplayName("배열이 아니면 400")
    void notArray() {
        assertThatThrownBy(() -> goodsJson.validatePersonLayers(mapper.readTree("{\"layerOrder\":0}")))
                .isInstanceOf(GoodsInvalidLayersException.class);
        assertThatThrownBy(() -> goodsJson.validatePersonLayers(null))
                .isInstanceOf(GoodsInvalidLayersException.class);
    }

    @Test
    @DisplayName("상세 응답에는 key 옆에 URL 이 붙고, 원본과 나머지 필드는 그대로다")
    void urlsAdded() {
        JsonNode original = mapper.readTree("""
                [{"cutoutKey":"c1.png","depthMapKey":"d1.png","layerOrder":0,"left":0.1,
                  "parts":[{"partMapKey":"p1.png","name":"head"},{"name":"no-key"}]},
                 {"cutoutKey":null,"layerOrder":1}]
                """);

        JsonNode enriched = goodsJson.personLayersWithUrls(original, imageStorage);

        assertThat(enriched.get(0).get("cutoutUrl").stringValue()).isEqualTo("https://cdn.example/c1.png");
        assertThat(enriched.get(0).get("depthMapUrl").stringValue()).isEqualTo("https://cdn.example/d1.png");
        assertThat(enriched.get(0).get("parts").get(0).get("partMapUrl").stringValue())
                .isEqualTo("https://cdn.example/p1.png");
        // key 가 없는 원소는 손대지 않는다.
        assertThat(enriched.get(0).get("parts").get(1).has("partMapUrl")).isFalse();
        assertThat(enriched.get(0).get("left").asDouble()).isEqualTo(0.1);
        // key 가 null 이면 URL 도 없다.
        assertThat(enriched.get(1).has("cutoutUrl")).isFalse();
        // 원본은 그대로다.
        assertThat(original.get(0).has("cutoutUrl")).isFalse();
    }

    @Test
    @DisplayName("JSON null 은 SQL NULL 로 저장한다")
    void nullNodeToNull() {
        assertThat(goodsJson.write(null)).isNull();
        assertThat(goodsJson.write(mapper.readTree("null"))).isNull();
        assertThat(goodsJson.write(mapper.readTree("{\"a\":1}"))).isEqualTo("{\"a\":1}");
        assertThat(goodsJson.read(null)).isNull();
    }
}
