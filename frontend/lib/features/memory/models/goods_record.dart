import '../utils/concert_datetime.dart';
import 'ticket_effect.dart';

/// 소장품을 만들 때 서버가 함께 저장해 둔 공연 정보.
///
/// 서버가 티켓에서 채운다(`GoodsJson.concertSnapshot`). 앱이 보낸 값이 아니라서,
/// 복원한 소장품의 뒷면은 서버가 기억하는 공연 정보로 찍힌다.
class ConcertSnapshot {
  const ConcertSnapshot({this.title, this.artist, this.date, this.venue});

  /// 없을 수 있다 — 아티스트가 없는 공연은 null 로 저장된다.
  final String? title, artist, venue;

  /// ISO `LocalDateTime` 문자열. 화면 문구로 바꾸는 일은 [details] 가 한다.
  final String? date;

  factory ConcertSnapshot.fromJson(Map<String, dynamic>? json) =>
      ConcertSnapshot(
        title: json?['title'] as String?,
        artist: json?['artist'] as String?,
        date: json?['date'] as String?,
        venue: json?['venue'] as String?,
      );

  /// 티켓 뒷면에 인쇄할 사실들.
  ///
  /// 키는 `MemoryConcert.ticketDetails` 와 같다. 이 기기에서 만든 소장품과
  /// 서버에서 복원한 소장품의 뒷면이 같은 줄을 같은 순서로 보여야 한다.
  Map<String, String> get details => {
    '공연명': ?title,
    '아티스트': ?artist,
    '날짜': ?_date,
    '시간': ?_time,
    '장소': ?venue,
  };

  String? get _date {
    final formatted = ConcertDateTime.date(date);
    return formatted.isEmpty ? null : formatted;
  }

  String? get _time => ConcertDateTime.time(date);
}

/// 내 소장품 목록의 한 장. 카드에 필요한 것만 있다.
class GoodsSummary {
  const GoodsSummary({
    required this.goodsId,
    required this.ticketId,
    required this.effect,
    required this.snapshot,
    this.previewUrl,
  });

  final String goodsId, ticketId;

  /// 카드에 쓸 미리보기 주소. 만들 때 미리보기를 올리지 않았으면 null.
  final String? previewUrl;
  final TicketEffect effect;
  final ConcertSnapshot snapshot;

  factory GoodsSummary.fromJson(Map<String, dynamic> json) => GoodsSummary(
    goodsId: '${json['goodsId']}',
    ticketId: '${json['ticketId']}',
    previewUrl: json['previewUrl'] as String?,
    effect: TicketEffect.fromWire(json['effectType'] as String?),
    snapshot: ConcertSnapshot.fromJson(
      json['concertSnapshot'] as Map<String, dynamic>?,
    ),
  );
}

/// 소장품 상세. **다른 기기에서 이 응답만으로 복원하는 기준**이라 저장된 것이
/// 전부 실려 온다.
///
/// 이미지는 key 와 주소가 함께 온다. 주소는 지금 읽을 수 있는 것이고(만료될 수
/// 있다) key 는 그 이미지의 이름이다. 앱은 내려받을 때 주소를, 같은 이미지인지
/// 따질 때 key 를 쓴다.
class GoodsDetail {
  const GoodsDetail({
    required this.goodsId,
    required this.ticketId,
    required this.concertId,
    required this.clientGoodsId,
    required this.effect,
    required this.snapshot,
    required this.personLayers,
    this.backgroundUrl,
    this.sourceBackgroundUrl,
    this.personCompositeUrl,
    this.depthMapUrl,
    this.previewUrl,
    this.backgroundFraming,
    this.transitionConfig,
    this.renderMetadata,
  });

  final String goodsId, ticketId, concertId, clientGoodsId;

  /// 배경만 필수 컬럼이지만, 주소는 저장소가 말썽일 때 비어 올 수 있어 전부
  /// 선택으로 둔다. 배경이 없으면 복원할 수 없다는 판단은 복원 쪽이 한다.
  final String? backgroundUrl,
      sourceBackgroundUrl,
      personCompositeUrl,
      depthMapUrl,
      previewUrl;

  final TicketEffect effect;
  final ConcertSnapshot snapshot;

  /// 앱이 만든 JSON 이 그대로 돌아온다. 서버는 구조를 해석하지 않는다.
  final Map<String, dynamic>? backgroundFraming, transitionConfig;
  final Map<String, dynamic>? renderMetadata;
  final List<Map<String, dynamic>> personLayers;

  factory GoodsDetail.fromJson(Map<String, dynamic> json) => GoodsDetail(
    goodsId: '${json['goodsId']}',
    ticketId: '${json['ticketId']}',
    concertId: '${json['concertId']}',
    clientGoodsId: json['clientGoodsId'] as String? ?? '',
    backgroundUrl: json['backgroundUrl'] as String?,
    sourceBackgroundUrl: json['sourceBackgroundUrl'] as String?,
    personCompositeUrl: json['personCompositeUrl'] as String?,
    depthMapUrl: json['depthMapUrl'] as String?,
    previewUrl: json['previewUrl'] as String?,
    effect: TicketEffect.fromWire(json['effectType'] as String?),
    snapshot: ConcertSnapshot.fromJson(
      json['concertSnapshot'] as Map<String, dynamic>?,
    ),
    backgroundFraming: json['backgroundFraming'] as Map<String, dynamic>?,
    transitionConfig: json['transitionConfig'] as Map<String, dynamic>?,
    renderMetadata: json['renderMetadata'] as Map<String, dynamic>?,
    personLayers: [
      for (final layer in json['personLayers'] as List? ?? const [])
        if (layer is Map) Map<String, dynamic>.from(layer),
    ],
  );
}
