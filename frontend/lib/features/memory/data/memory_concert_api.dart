import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../constants.dart';
import '../models/concert_kit.dart';
import '../models/memory_concert.dart';
import '../utils/concert_datetime.dart';

/// 소장품을 만들 수 있는 공연 목록 — 내가 입장을 마친 티켓들.
///
/// 앱은 [HttpMemoryConcertApi] 를 쓴다. [MockMemoryConcertApi] 는 서버 없이
/// 화면을 띄우는 테스트와 데모용으로 남겨 둔다.
abstract interface class MemoryConcertApi {
  Future<List<MemoryConcert>> getConcerts();

  /// 이 공연의 제작 소재. 그 공연 티켓을 지금 가진 사람에게만 열린다.
  ///
  /// 소재가 없는 공연이 정상이라 빈 묶음이 올 수 있다. 데모로 채우는 일은
  /// 화면이 한다([ConcertKit.orDemo]).
  Future<ConcertKit> getKit(String concertId);
}

class MockMemoryConcertApi implements MemoryConcertApi {
  @override
  Future<ConcertKit> getKit(String concertId) async => ConcertKit.demo;

  @override
  Future<List<MemoryConcert>> getConcerts() async => const [
    MemoryConcert(
      ticketId: 'ticket-1024',
      id: 'concert-1024',
      title: '빛으로 남은 밤',
      artist: 'TIMO STAGE',
      date: '2026.09.26',
      time: '19:00',
      venue: '서울 메모리 홀',
      poster: 'assets/demo/stage_blue.png',
      videoUrl: CatalogConstants.demoVideoAsset,
    ),
    MemoryConcert(
      ticketId: 'ticket-2048',
      id: 'concert-2048',
      title: '우리의 여름, 앙코르',
      artist: 'TIMO BAND',
      date: '2026.10.03',
      time: '19:00',
      venue: '올림픽 메모리 파크',
      poster: 'assets/demo/stage_gold.png',
      videoUrl: CatalogConstants.demoVideoAsset,
    ),
    MemoryConcert(
      ticketId: 'ticket-3072',
      id: 'concert-3072',
      title: '핑크 노이즈 나이트',
      artist: 'TIMO CREW',
      date: '2026.10.17',
      time: '19:00',
      venue: '부산 메모리 아레나',
      poster: 'assets/demo/stage_pink.png',
      videoUrl: CatalogConstants.demoVideoAsset,
    ),
    MemoryConcert(
      ticketId: 'ticket-4096',
      id: 'concert-4096',
      title: '첫눈 전야제',
      artist: 'TIMO STAGE',
      date: '2026.11.21',
      time: '19:00',
      venue: '서울 메모리 홀',
      poster: 'assets/demo/stage_blue.png',
      videoUrl: CatalogConstants.demoVideoAsset,
    ),
    MemoryConcert(
      ticketId: 'ticket-5120',
      id: 'concert-5120',
      title: '골든 아워 페스타',
      artist: 'TIMO BAND',
      date: '2026.12.05',
      time: '19:00',
      venue: '인천 메모리 돔',
      poster: 'assets/demo/stage_gold.png',
      videoUrl: CatalogConstants.demoVideoAsset,
    ),
    MemoryConcert(
      ticketId: 'ticket-6144',
      id: 'concert-6144',
      title: '카운트다운 스테이지',
      artist: 'TIMO CREW',
      date: '2026.12.31',
      time: '19:00',
      venue: '올림픽 메모리 파크',
      poster: 'assets/demo/stage_pink.png',
      videoUrl: CatalogConstants.demoVideoAsset,
    ),
  ];
}

/// 백엔드 카탈로그(`/api/v1/collectibles/concerts`)에 실제로 요청하는 구현.
///
/// **로그인이 필요하다.** 서버는 요청한 회원이 입장을 마친 티켓만 준다. 토큰은
/// `AuthInterceptor` 가 붙인다.
///
/// 한 줄은 공연이 아니라 티켓이다. 같은 공연을 두 번 갔으면 줄도 두 개고,
/// 페이지는 없다 — 한 사람이 입장까지 마친 티켓은 많아야 수십 장이다.
class HttpMemoryConcertApi implements MemoryConcertApi {
  HttpMemoryConcertApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const concertsPath = '/api/v1/collectibles/concerts';
  static const kitPath = '/api/v1/concerts';

  final Dio _dio;

  @override
  Future<ConcertKit> getKit(String concertId) async {
    try {
      final response = await _dio.get<dynamic>('$kitPath/$concertId/kit');
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw const ApiException(CreatorText.kitFailed);
      }
      return ConcertKit(
        backgrounds: _assets(body['backgrounds']),
        people: _assets(body['people']),
      );
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// 소재 주소들, 서버가 준 순서대로(`sortOrder` 순). 주소는 저장소 key 일 수
  /// 있어 절대 주소로 바꾼다 — 포스터와 같다.
  static List<KitAsset> _assets(Object? list) => [
    for (final item in list as List? ?? const [])
      if (item is Map && ApiClient.imageUrl(item['url'] as String?) != null)
        KitAsset(ApiClient.imageUrl(item['url'] as String?)!),
  ];

  @override
  Future<List<MemoryConcert>> getConcerts() async {
    try {
      final response = await _dio.get<dynamic>(concertsPath);
      final body = response.data;
      if (body is! List) {
        throw const ApiException('공연 정보를 불러오지 못했어요.');
      }
      return body.cast<Map<String, dynamic>>().map(_concert).toList();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }

  /// 응답 한 줄을 카탈로그 한 줄로.
  ///
  /// 서버는 식별자를 숫자로 주고 앱은 문자열로 다룬다 — 숫자로 계산할 일이
  /// 없고, 요청 경로에 넣을 때도 문자열이다.
  static MemoryConcert _concert(Map<String, dynamic> json) {
    // 서버는 날짜와 시각을 LocalDateTime 한 값으로 준다. 화면은 둘을 따로 쓴다.
    final startsAt = json['date'] as String?;

    return MemoryConcert(
      ticketId: '${json['ticketId']}',
      id: '${json['concertId']}',
      title: json['title'] as String? ?? '',
      // 출연 아티스트가 없는 공연은 null 로 온다.
      artist: json['artist'] as String? ?? '',
      date: ConcertDateTime.date(startsAt),
      time: ConcertDateTime.time(startsAt),
      venue: json['venue'] as String? ?? '',
      // 포스터는 저장소 key 로 온다. 앱이 읽을 절대 주소로 바꾼다.
      poster: ApiClient.imageUrl(json['thumbnailUrl'] as String?) ?? '',
      // 공연에 영상 컬럼이 없어 늘 null 이다. 몰입 영상 자리를 비울 수는 없어
      // 앱에 든 데모 영상으로 채운다.
      videoUrl: json['videoUrl'] as String? ?? CatalogConstants.demoVideoAsset,
      goodsId: json['goodsId'] == null ? null : '${json['goodsId']}',
    );
  }
}
