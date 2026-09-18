package com.ssafy.timo.domain.goods.service;

import com.ssafy.timo.domain.artist.entity.Artist;
import com.ssafy.timo.domain.concert.entity.Concert;
import com.ssafy.timo.domain.goods.exception.GoodsInvalidLayersException;
import com.ssafy.timo.global.storage.ImageStorage;
import java.time.format.DateTimeFormatter;
import java.util.HashSet;
import java.util.Set;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ObjectNode;

/**
 * 굿즈의 JSON 컬럼을 다루는 유일한 곳.
 *
 * <p>엔티티는 JSON 을 문자열로만 들고 있고({@code Goods} 주석), 트리로 읽는 일은 세 가지뿐이다 —
 * {@code personLayers} 의 길이·순서 검증, 상세 응답에 {@code *Url} 을 덧붙이는 일, 그리고 생성 시점의
 * 공연 스냅샷 만들기. 그 밖의 구조는 해석하지 않는다.
 *
 * <p>{@code ObjectMapper} 는 Spring 이 만든 것을 받는다({@code tools.jackson}, Jackson 3). 웹 계층과
 * 같은 설정으로 읽고 써야 앱이 보낸 그대로가 저장되고, 저장된 그대로가 응답에 나간다.
 */
@Component
@RequiredArgsConstructor
public class GoodsJson {

    /** 상세 응답의 {@code personLayers[]} 원소에서 URL 을 붙일 key 와 그 이름. */
    private static final String CUTOUT_KEY = "cutoutKey";
    private static final String CUTOUT_URL = "cutoutUrl";
    private static final String DEPTH_MAP_KEY = "depthMapKey";
    private static final String DEPTH_MAP_URL = "depthMapUrl";
    private static final String PARTS = "parts";
    private static final String PART_MAP_KEY = "partMapKey";
    private static final String PART_MAP_URL = "partMapUrl";
    private static final String LAYER_ORDER = "layerOrder";

    static final int MAX_PERSON_LAYERS = 2;

    private final ObjectMapper objectMapper;

    /** 트리를 저장할 문자열로. {@code null} 이나 JSON {@code null} 은 SQL {@code NULL} 이다. */
    public String write(JsonNode node) {
        if (node == null || node.isNull()) {
            return null;
        }
        return objectMapper.writeValueAsString(node);
    }

    /** 저장된 문자열을 트리로. {@code NULL} 컬럼은 {@code null} 이다. */
    public JsonNode read(String json) {
        if (json == null) {
            return null;
        }
        return objectMapper.readTree(json);
    }

    /**
     * {@code personLayers} 규칙: 배열이고, 길이가 {@value #MAX_PERSON_LAYERS} 이하이고,
     * 원소의 {@code layerOrder} 가 겹치지 않는다. 그 밖의 필드는 보지 않는다.
     *
     * <p>{@code layerOrder} 가 없는 원소는 "순서 없음" 하나로 취급한다. 둘 다 없으면 겹친 것이다 —
     * 어느 쪽이 위인지 정할 수 없어 앱이 복원할 수 없기 때문이다.
     */
    public void validatePersonLayers(JsonNode personLayers) {
        if (personLayers == null || !personLayers.isArray()) {
            throw new GoodsInvalidLayersException("personLayers 는 배열이어야 합니다");
        }
        if (personLayers.size() > MAX_PERSON_LAYERS) {
            throw new GoodsInvalidLayersException(
                    "personLayers 는 최대 " + MAX_PERSON_LAYERS + "개입니다 (" + personLayers.size() + "개)");
        }

        Set<String> seenOrders = new HashSet<>();
        for (JsonNode layer : personLayers) {
            JsonNode order = layer.path(LAYER_ORDER);
            String key = order.isMissingNode() || order.isNull() ? "" : order.toString();
            if (!seenOrders.add(key)) {
                throw new GoodsInvalidLayersException("layerOrder 가 겹칩니다 (" + key + ")");
            }
        }
    }

    /**
     * 상세 응답용. 저장된 {@code personLayers} 를 복사해 key 옆에 {@code *Url} 을 덧붙인다.
     *
     * <p>원소가 객체이고 해당 key 가 문자열일 때만 붙인다. 앱이 정한 구조를 서버가 강제하지 않으므로
     * 모양이 달라도 실패시키지 않고 그대로 통과시킨다. 원본 트리는 건드리지 않는다.
     */
    public JsonNode personLayersWithUrls(JsonNode personLayers, ImageStorage imageStorage) {
        if (personLayers == null || !personLayers.isArray()) {
            return personLayers;
        }

        JsonNode copy = personLayers.deepCopy();
        for (JsonNode layer : copy) {
            if (!(layer instanceof ObjectNode layerNode)) {
                continue;
            }
            addUrl(layerNode, CUTOUT_KEY, CUTOUT_URL, imageStorage);
            addUrl(layerNode, DEPTH_MAP_KEY, DEPTH_MAP_URL, imageStorage);

            for (JsonNode part : layerNode.path(PARTS)) {
                if (part instanceof ObjectNode partNode) {
                    addUrl(partNode, PART_MAP_KEY, PART_MAP_URL, imageStorage);
                }
            }
        }
        return copy;
    }

    private static void addUrl(ObjectNode node, String keyField, String urlField, ImageStorage imageStorage) {
        JsonNode key = node.path(keyField);
        if (key.isString()) {
            node.put(urlField, imageStorage.getUrl(key.stringValue()));
        }
    }

    /**
     * 생성 시점의 공연 스냅샷 {@code { title, artist, date, venue }}.
     *
     * <p>아티스트는 이름을 {@code ", "} 로 이은 한 줄이다. 소장품 목록({@code findCollectibleConcerts})이
     * {@code group_concat} 으로 만드는 것과 같은 모양이라 화면이 두 곳을 같은 코드로 그린다.
     * 날짜는 응답의 {@code LocalDateTime} 과 같은 ISO 형식이다.
     */
    public String concertSnapshot(Concert concert) {
        ObjectNode snapshot = objectMapper.createObjectNode();
        snapshot.put("title", concert.getTitle());
        snapshot.put("artist", joinArtists(concert));
        snapshot.put("date", concert.getStartDate() == null
                ? null
                : concert.getStartDate().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
        snapshot.put("venue", concert.getVenue().getName());
        return objectMapper.writeValueAsString(snapshot);
    }

    private static String joinArtists(Concert concert) {
        if (concert.getArtists().isEmpty()) {
            return null;
        }
        return concert.getArtists().stream()
                .map(Artist::getName)
                .collect(Collectors.joining(", "));
    }
}
