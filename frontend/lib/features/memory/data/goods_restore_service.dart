import 'dart:io';
import 'dart:ui';

import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/goods_record.dart';
import '../models/memory_ticket.dart';
import '../models/person_depth_layer.dart';
import '../models/photo_framing.dart';
import 'goods_api.dart';
import 'image_download.dart';

/// 이미지 한 장을 주소에서 받아 기기 파일로 쓴다. 테스트가 갈아 끼운다.
typedef ImageDownloader = Future<void> Function(String url, String targetPath);

/// 서버에 있는 소장품을 이 기기로 가져온다.
///
/// 소장품 화면은 전부 기기 파일 경로로 그린다(`LocalImage`·깊이 셰이더가
/// 파일을 직접 읽는다). 그래서 다른 기기에서 만든 소장품을 보려면 상세 응답의
/// 주소마다 이미지를 내려받아 [MemoryTicket] 을 **이 기기 경로로** 다시
/// 조립해야 한다. 그 일을 여기서만 한다.
///
/// 내려받은 파일은 `photos/restored/{goodsId}/` 아래에 둔다. 만들 때 쓰는
/// `photos/` 와 섞이지 않게 하고, 같은 소장품을 다시 가져오면 같은 자리에
/// 덮어쓴다.
class GoodsRestoreService {
  GoodsRestoreService(
    this._api, {
    ImageDownloader? download,
    Future<Directory> Function()? documentsDirectory,
  }) : _download = download ?? downloadImage,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  final GoodsApi _api;
  final ImageDownloader _download;
  final Future<Directory> Function() _documentsDirectory;

  /// 상세를 받아 기기용 소장품으로. 배경 주소가 없으면 그릴 수 없어 실패다.
  Future<MemoryTicket> restore(String goodsId) async {
    final detail = await _api.fetchDetail(goodsId);
    return fromDetail(detail);
  }

  Future<MemoryTicket> fromDetail(GoodsDetail detail) async {
    final backgroundUrl = detail.backgroundUrl;
    if (backgroundUrl == null || backgroundUrl.isEmpty) {
      throw const ApiException(GoodsText.restoreFailed);
    }

    final root = await _documentsDirectory();
    final folder = Directory('${root.path}/photos/restored/${detail.goodsId}');
    await folder.create(recursive: true);

    Future<String?> fetch(String? url, String name) async {
      if (url == null || url.isEmpty) return null;
      final target = '${folder.path}/$name.${imageExtension(url)}';
      await _download(url, target);
      return target;
    }

    final layers = <PersonDepthLayer>[];
    for (var i = 0; i < detail.personLayers.length; i++) {
      final layer = await _layer(detail.personLayers[i], i, fetch);
      if (layer != null) layers.add(layer);
    }
    // 그리는 순서는 layerOrder 가 정한다. 서버는 겹치지 않는 것만 보장하고
    // 정렬은 하지 않는다.
    layers.sort((a, b) => a.order.compareTo(b.order));

    final metadata = detail.renderMetadata ?? const {};
    final framing = detail.backgroundFraming;

    return MemoryTicket(
      ticketId: detail.ticketId,
      concertId: detail.concertId,
      backgroundPath: (await fetch(backgroundUrl, 'background'))!,
      sourceBackgroundPath: await fetch(detail.sourceBackgroundUrl, 'source'),
      personCompositePath: await fetch(detail.personCompositeUrl, 'people'),
      depthMapPath: await fetch(detail.depthMapUrl, 'depth'),
      previewImagePath: await fetch(detail.previewUrl, 'preview'),
      backgroundFraming: framing == null
          ? null
          : PhotoFraming.fromJson(framing),
      manualPersonLayout: metadata['manualPersonLayout'] == true,
      personDepthLayers: layers,
      effectType: detail.effect.label,
      // 공연에 영상이 없어 만들 때도 데모 영상이었다. 복원도 같다.
      videoId: '${detail.concertId}-main',
      videoUrl: CatalogConstants.demoVideoAsset,
      details: detail.snapshot.details,
      // 배경 시차 밴드는 올리지 않았다. 깊이 맵이 있으면 셰이더가 대신한다.
      depthLayers: const [],
      demoDepth: metadata['demoDepth'] == true,
      transition: detail.transitionConfig ?? const {},
      processingNotes: const [GoodsText.restoredNote],
      // 서버에 있는 것은 이미 확정된 것이다.
      confirmed: true,
      goodsId: detail.goodsId,
    );
  }

  /// 인물 층 하나. 컷아웃이 없으면 그릴 것이 없어 건너뛴다.
  Future<PersonDepthLayer?> _layer(
    Map<String, dynamic> json,
    int index,
    Future<String?> Function(String? url, String name) fetch,
  ) async {
    final cutout = await fetch(json['cutoutUrl'] as String?, 'layer$index');
    if (cutout == null) return null;

    final parts = [
      for (final part in json['parts'] as List? ?? const [])
        if (part is Map) Map<String, dynamic>.from(part),
    ];
    // 부위 맵은 층에 한 장이다. 올릴 때 부위마다 같은 key 를 실었으므로
    // 어느 부위의 주소든 같다 — 첫 부위 것을 쓴다.
    final partMapUrl = parts.isEmpty
        ? null
        : parts.first['partMapUrl'] as String?;

    return PersonDepthLayer(
      path: cutout,
      depthMapPath: await fetch(
        json['depthMapUrl'] as String?,
        'layer$index-depth',
      ),
      partMapPath: await fetch(partMapUrl, 'layer$index-parts'),
      parts: [
        for (final part in parts)
          if (part['label'] is String)
            PersonPart(
              label: part['label'] as String,
              depth: (part['depth'] as num?)?.toDouble() ?? 0,
              share: (part['share'] as num?)?.toDouble() ?? 0,
            ),
      ],
      layered: json['layered'] == true,
      strength: PersonDepthStrength.fromName(json['depthStrength']),
      order: (json['layerOrder'] as num?)?.toInt() ?? index,
      placement: Rect.fromLTWH(
        _double(json['left']),
        _double(json['top']),
        _double(json['width'], fallback: 1),
        _double(json['height'], fallback: 1),
      ),
    );
  }

  static double _double(Object? value, {double fallback = 0}) =>
      value is num ? value.toDouble() : fallback;
}
