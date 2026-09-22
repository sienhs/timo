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
    this.confirmed = false,
    this.goodsId,
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

  /// 확정했는가. 확정하기 전에는 기기에만 있고 고칠 수 있다. 확정하면 서버로
  /// 가고 그 뒤로는 고치지도 지우지도 못한다 — 서버에 수정·삭제가 없다.
  final bool confirmed;

  /// 서버가 매긴 소장품 번호. 확정(또는 복원)하고 나서만 있다.
  ///
  /// [confirmed] 와 겹쳐 보이지만 쓰임이 다르다. 저쪽은 "고칠 수 있는가" 이고
  /// 이건 "서버의 어느 소장품인가" 다 — 상세를 다시 받아 오려면 번호가 있어야
  /// 한다.
  final String? goodsId;
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
    bool? confirmed,
    String? goodsId,
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
    confirmed: confirmed ?? this.confirmed,
    goodsId: goodsId ?? this.goodsId,
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
    'confirmed': confirmed,
    'goodsId': goodsId,
  };

  /// 서버에 올릴 이미지의 기기 경로 — 컬럼 자리 다섯 장과 인물 레이어의 것들.
  ///
  /// 순서가 [toGoodsJson] 의 key 표를 만드는 순서다. 같은 파일을 두 자리가
  /// 가리키는 경우가 있어(배경 원본을 그대로 쓴 소장품) 중복은 한 번만 올린다.
  List<String> get imagePaths => {
    backgroundPath,
    ?sourceBackgroundPath,
    ?personCompositePath,
    ?depthMapPath,
    ?previewImagePath,
    for (final layer in personDepthLayers) ...[
      layer.path,
      ?layer.depthMapPath,
      ?layer.partMapPath,
    ],
  }.toList();

  /// 서버로 올릴 생성 요청 본문(백엔드 `CreateGoodsCommand`).
  ///
  /// [toJson] 은 Hive 로컬 저장용이라 기기 절대 경로를 그대로 담는다. 그 경로는
  /// 다른 기기에서 아무 의미가 없으므로 서버용은 따로 만든다.
  ///
  /// 이미지는 앱이 먼저 올리고 저장소 key 를 받아 오는 구조다. [keys] 는 그
  /// 결과인 `기기 경로 → 저장소 key` 표다. 표에 없는 경로는 null 로 둔다 —
  /// 배경만 예외로, 서버가 필수로 받으므로 빠지면 즉시 실패시킨다. 여기서
  /// 던지지 않으면 서버가 거절할 때까지 알 수 없다.
  ///
  /// **회원·공연·공연 스냅샷은 보내지 않는다.** 요청자는 토큰에서, 공연은
  /// 티켓에서 서버가 정한다 — 클라이언트가 보낸 값을 신원이나 소속으로 쓰지
  /// 않는다는 것이 서버 규약이다(백엔드 `GoodsCreateApi`). 만든 시각도 서버가
  /// 찍는다.
  Map<String, dynamic> toGoodsJson({required Map<String, String> keys}) {
    String? keyFor(String? path) => path == null ? null : keys[path];

    final backgroundKey = keyFor(backgroundPath);
    if (backgroundKey == null) {
      throw ArgumentError.value(
        backgroundPath,
        'keys',
        '배경 이미지의 저장소 key 가 없습니다. 업로드 후 keys 에 넣어주세요.',
      );
    }

    return {
      // 멱등 키. 티켓 한 장에 소장품은 하나라 티켓 번호가 곧 이 소장품의
      // 이름이다 — 응답이 오다 끊겨 다시 눌러도 같은 값이 가고, 서버는 새로
      // 만드는 대신 먼저 만든 것을 돌려준다.
      'clientGoodsId': ticketId,
      'backgroundKey': backgroundKey,
      'sourceBackgroundKey': keyFor(sourceBackgroundPath),
      'personCompositeKey': keyFor(personCompositePath),
      'depthMapKey': keyFor(depthMapPath),
      'previewKey': keyFor(previewImagePath),
      // effectType 에는 화면에 쓰는 한국어 라벨('꽃가루')이 들어 있다. 서버
      // ENUM 은 영문 이름이므로 enum 을 거쳐 보낸다.
      'effectType': effect.name,
      'backgroundFraming': backgroundFraming?.toJson(),
      'personLayers': [
        for (final layer in personDepthLayers)
          {
            'cutoutKey': keyFor(layer.path),
            'depthMapKey': keyFor(layer.depthMapPath),
            'depthStrength': layer.strength.name,
            'layered': layer.layered,
            'left': layer.placement.left,
            'top': layer.placement.top,
            'width': layer.placement.width,
            'height': layer.placement.height,
            // 서버가 보는 유일한 필드다. 겹치면 400 이라 층마다 다른 값이어야
            // 한다(백엔드 `GoodsJson.validatePersonLayers`).
            'layerOrder': layer.order,
            // 부위 맵은 층에 한 장뿐인데도 부위마다 넣는다. 서버가 읽을 수 있는
            // 주소(`partMapUrl`)를 붙여 주는 자리가 `parts[].partMapKey` 뿐이라
            // 그렇다 — 층에만 두면 복원할 때 그 이미지를 받아 올 주소가 없다.
            'parts': [
              for (final part in layer.parts)
                {...part.toJson(), 'partMapKey': keyFor(layer.partMapPath)},
            ],
          },
      ],
      'transitionConfig': _goodsTransition(),
      // depthLayers(배경 시차용 밴드 PNG)는 넣지 않는다. 로컬 경로일 뿐이고
      // 다른 기기에서 의미가 없다. 복원은 depthMapKey 로 셰이더가 다시 만든다.
      'renderMetadata': {
        'demoDepth': demoDepth,
        'manualPersonLayout': manualPersonLayout,
      },
    };
  }

  /// `transitionConfig` 는 서버가 필수로 받고 키가 모두 있어야 한다.
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
    // 확정 개념이 생기기 전에 저장된 것은 이미 만들어 둔 소장품이다. 임시로
    // 되돌리면 멀쩡한 소장품에 '임시' 딱지가 붙는다.
    confirmed: j['confirmed'] as bool? ?? true,
    goodsId: j['goodsId'] as String?,
  );
}
