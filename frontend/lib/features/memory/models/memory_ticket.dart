import 'ticket_effect.dart';
import 'photo_framing.dart';
import 'person_depth_layer.dart';

class MemoryTicket {
  const MemoryTicket({
    required this.ticketId,
    required this.concertId,
    required this.backgroundPath,
    required this.personCompositePath,
    required this.effectType,
    required this.videoId,
    required this.videoUrl,
    required this.details,
    required this.depthLayers,
    required this.demoDepth,
    this.ownerId = 'local-demo',
    this.sourceBackgroundPath,
    this.backgroundFraming,
    this.manualPersonLayout = false,
    this.personDepthLayers = const [],
    this.previewImagePath,
    this.depthMapPath,
    this.processingNotes = const [],
    this.transition = const {},
  });
  final String ticketId,
      concertId,
      ownerId,
      backgroundPath,
      effectType,
      videoId,
      videoUrl;
  final String? sourceBackgroundPath,
      previewImagePath,
      depthMapPath,
      personCompositePath;
  final PhotoFraming? backgroundFraming;
  final bool manualPersonLayout;
  final List<PersonDepthLayer> personDepthLayers;
  final Map<String, String> details;
  final List<String> depthLayers, processingNotes;
  final bool demoDepth;
  final Map<String, dynamic> transition;
  TicketEffect get effect => TicketEffect.fromLabel(effectType);

  /// Copy with a re-rendered background (used when an older ticket is
  /// upgraded to the full-bleed extended background).
  MemoryTicket copyWith({
    String? backgroundPath,
    List<String>? depthLayers,
    String? depthMapPath,
    bool? demoDepth,
    List<String>? processingNotes,
    List<PersonDepthLayer>? personDepthLayers,
    String? effectType,
  }) => MemoryTicket(
    ticketId: ticketId,
    concertId: concertId,
    ownerId: ownerId,
    backgroundPath: backgroundPath ?? this.backgroundPath,
    sourceBackgroundPath: sourceBackgroundPath,
    backgroundFraming: backgroundFraming,
    personCompositePath: personCompositePath,
    manualPersonLayout: manualPersonLayout,
    personDepthLayers: personDepthLayers ?? this.personDepthLayers,
    previewImagePath: previewImagePath,
    depthMapPath: depthMapPath ?? this.depthMapPath,
    effectType: effectType ?? this.effectType,
    videoId: videoId,
    videoUrl: videoUrl,
    details: details,
    depthLayers: depthLayers ?? this.depthLayers,
    demoDepth: demoDepth ?? this.demoDepth,
    processingNotes: processingNotes ?? this.processingNotes,
    transition: transition,
  );
  Map<String, dynamic> toJson() => {
    'ticketId': ticketId,
    'concertId': concertId,
    'ownerId': ownerId,
    'backgroundPath': backgroundPath,
    'sourceBackgroundPath': sourceBackgroundPath,
    'backgroundFraming': backgroundFraming?.toJson(),
    'personCompositePath': personCompositePath,
    'manualPersonLayout': manualPersonLayout,
    'personDepthLayers': personDepthLayers.map((p) => p.toJson()).toList(),
    'previewImagePath': previewImagePath,
    'depthMapPath': depthMapPath,
    'effectType': effectType,
    'videoId': videoId,
    'videoUrl': videoUrl,
    'details': details,
    'depthLayers': depthLayers,
    'demoDepth': demoDepth,
    'processingNotes': processingNotes,
    'transition': transition,
  };

  /// 서버(`goods` 단일 테이블)로 올릴 페이로드.
  ///
  /// [toJson] 은 Hive 로컬 저장용이라 기기 절대 경로를 그대로 담는다. 그 경로는
  /// 다른 기기에서 아무 의미가 없으므로 서버용은 따로 만든다.
  ///
  /// 이미지는 앱이 먼저 올리고 S3 object key 를 받아 오는 구조다. [keys] 는
  /// 그 결과인 `로컬 경로 → S3 키` 표다. 표에 없는 경로는 null 로 둔다 —
  /// 배경만 예외로, `background_key` 가 NOT NULL 이라 빠지면 즉시 실패시킨다.
  /// 여기서 던지지 않으면 서버가 500 으로 거절할 때까지 알 수 없다.
  ///
  /// `member_id` 는 서버가 토큰으로 판별하므로 보내지 않는다. `ownerId` 도
  /// 마찬가지다(로컬 전용 값). `created_at`·`updated_at` 은 서버가 채운다.
  Map<String, dynamic> toGoodsJson({required Map<String, String> keys}) {
    String? keyFor(String? path) => path == null ? null : keys[path];

    final backgroundKey = keyFor(backgroundPath);
    if (backgroundKey == null) {
      throw ArgumentError.value(
        backgroundPath,
        'keys',
        '배경 이미지의 S3 키가 없습니다. 업로드 후 keys 에 넣어주세요.',
      );
    }

    return {
      'client_goods_id': ticketId,
      // TODO(S15P21D206-309): concert_id 는 DB 가 BIGINT 인데 앱은
      // 'concert-1024' 같은 문자열을 쓴다. 앱이 숫자만 뽑아 보낼지 서버가
      // 문자열을 받을지 정해야 한다. 정해지기 전까지는 원본을 그대로 보낸다.
      'concert_id': concertId,
      'background_key': backgroundKey,
      'source_background_key': keyFor(sourceBackgroundPath),
      'person_composite_key': keyFor(personCompositePath),
      'depth_map_key': keyFor(depthMapPath),
      'preview_key': keyFor(previewImagePath),
      // effectType 에는 화면에 쓰는 한국어 라벨('꽃가루')이 들어 있다. 서버
      // ENUM 은 영문 이름이므로 enum 을 거쳐 보낸다.
      // TODO(S15P21D206-309): DDL 의 effect_type ENUM 에 'godRays' 가 빠져
      // 있다. 앱은 정상적으로 보내므로 서버 쪽 ENUM 에 추가가 필요하다.
      'effect_type': effect.name,
      'background_framing': backgroundFraming?.toJson(),
      'person_layers': [
        for (final layer in personDepthLayers)
          {
            'cutout_key': keyFor(layer.path),
            'depth_map_key': keyFor(layer.depthMapPath),
            'depth_strength': layer.strength.name,
            'left': layer.placement.left,
            'top': layer.placement.top,
            'width': layer.placement.width,
            'height': layer.placement.height,
            'layer_order': layer.order,
            // TODO(S15P21D206-309): 신체 부위 층(partMapPath·parts)을 담을
            // 자리가 DDL 에 없다. 빠지면 다른 기기에서 복원할 때 부위별
            // 입체감 없이 단일 깊이로 떨어진다.
          },
      ],
      'transition_config': _goodsTransition(),
      // depthLayers(배경 시차용 밴드 PNG)는 넣지 않는다. 로컬 경로일 뿐이고
      // 다른 기기에서 의미가 없다. 복원은 depth_map_key 로 셰이더가 다시 만든다.
      'render_metadata': {
        'demoDepth': demoDepth,
        'manualPersonLayout': manualPersonLayout,
      },
      // details 에는 좌석·게이트·예매 번호·입장 안내도 있지만 소장품에는
      // 저장하지 않기로 했다(docs/ERD_SERVICE_INTEGRATION.md).
      'concert_snapshot': {
        'title': details['공연명'],
        'artist': details['아티스트'],
        'date': details['날짜'],
        'venue': details['장소'],
      },
    };
  }

  /// `transition_config` 는 NOT NULL 이고 키가 모두 있어야 한다.
  ///
  /// 전환 분석이 실패하면 `{'firstFrameAnalyzed': false}` 한 키만 남으므로
  /// 빠진 키를 중립값으로 채운다. 중립값은 네이티브 분석이 "사진과 영상 첫
  /// 프레임이 같다"(distance 0)고 판단했을 때 내놓는 값과 같다 —
  /// brightness 0, saturation 1, contrast 1+0*0.15, durationMs 550+150*0,
  /// blur 8+0*4.
  ///
  /// tint 만은 그 공식에 중립값이 없다(분석에 성공하면 사진 평균색이 들어간다).
  /// 지금 이 값을 읽는 코드는 앱 어디에도 없고, 실제로 쓰인다면 영상에 색을
  /// 입히는 곱셈일 가능성이 높아 항등원인 흰색을 넣는다. 검정을 넣으면 나중에
  /// 곱하는 순간 화면이 까맣게 죽는다.
  Map<String, dynamic> _goodsTransition() => {
    'brightness': transition['brightness'] ?? 0.0,
    'saturation': transition['saturation'] ?? 1.0,
    'contrast': transition['contrast'] ?? 1.0,
    'tint': transition['tint'] ?? 0xFFFFFFFF,
    'durationMs': transition['durationMs'] ?? 550,
    'blur': transition['blur'] ?? 8.0,
    'distance': transition['distance'] ?? 0.0,
    'firstFrameAnalyzed': transition['firstFrameAnalyzed'] == true,
  };

  /// 예전에 저장된 레코드에는 민팅 관련 키(mintStatus·tokenId·transactionHash·
  /// metadataUrl)가 남아 있다. 블록체인을 쓰지 않기로 하면서 읽지 않을 뿐이라
  /// 따로 옮길 것은 없다 — 모르는 키는 그냥 지나간다.
  factory MemoryTicket.fromJson(Map<String, dynamic> j) => MemoryTicket(
    ticketId: j['ticketId'] as String,
    concertId: j['concertId'] as String,
    ownerId: j['ownerId'] as String,
    backgroundPath: j['backgroundPath'] as String,
    sourceBackgroundPath: j['sourceBackgroundPath'] as String?,
    backgroundFraming: j['backgroundFraming'] == null
        ? null
        : PhotoFraming.fromJson(
            Map<String, dynamic>.from(j['backgroundFraming'] as Map),
          ),
    personCompositePath: j['personCompositePath'] as String?,
    manualPersonLayout: j['manualPersonLayout'] == true,
    personDepthLayers: [
      for (final p in j['personDepthLayers'] as List? ?? const [])
        PersonDepthLayer.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
    previewImagePath: j['previewImagePath'] as String?,
    depthMapPath: j['depthMapPath'] as String?,
    effectType: j['effectType'] as String,
    videoId: j['videoId'] as String,
    videoUrl: j['videoUrl'] as String,
    details: Map<String, String>.from(j['details'] as Map),
    depthLayers: List<String>.from(j['depthLayers'] as List),
    demoDepth: j['demoDepth'] as bool,
    processingNotes: List<String>.from(j['processingNotes'] as List? ?? []),
    transition: Map<String, dynamic>.from(j['transition'] as Map? ?? {}),
  );
}
