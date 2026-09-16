import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../models/memory_concert.dart';

/// 소장품을 만들 수 있는 공연 목록.
///
/// 지금은 [MockMemoryConcertApi] 로 붙어 있다. 소장품 카탈로그를 내려주는
/// 백엔드 주소가 아직 없어서다(docs/memory/BACKEND_API.md 의 `/concerts`). 서버가
/// 생기면 App 에서 [HttpMemoryConcertApi] 로 바꿔 넣기만 하면 되고, 화면은
/// 이 인터페이스만 보므로 손대지 않는다.
abstract interface class MemoryConcertApi {
  Future<List<MemoryConcert>> getConcerts();
}

class MockMemoryConcertApi implements MemoryConcertApi {
  @override
  Future<List<MemoryConcert>> getConcerts() async => const [
    MemoryConcert(
      id: 'concert-1024',
      title: '빛으로 남은 밤',
      artist: 'TIMO STAGE',
      date: '2026.09.26',
      venue: '서울 메모리 홀',
      poster: 'assets/demo/stage_blue.png',
      videoUrl: 'assets/videos/official_demo.mp4',
    ),
    MemoryConcert(
      id: 'concert-2048',
      title: '우리의 여름, 앙코르',
      artist: 'TIMO BAND',
      date: '2026.10.03',
      venue: '올림픽 메모리 파크',
      poster: 'assets/demo/stage_gold.png',
      videoUrl: 'assets/videos/official_demo.mp4',
    ),
    MemoryConcert(
      id: 'concert-3072',
      title: '핑크 노이즈 나이트',
      artist: 'TIMO CREW',
      date: '2026.10.17',
      venue: '부산 메모리 아레나',
      poster: 'assets/demo/stage_pink.png',
      videoUrl: 'assets/videos/official_demo.mp4',
    ),
    MemoryConcert(
      id: 'concert-4096',
      title: '첫눈 전야제',
      artist: 'TIMO STAGE',
      date: '2026.11.21',
      venue: '서울 메모리 홀',
      poster: 'assets/demo/stage_blue.png',
      videoUrl: 'assets/videos/official_demo.mp4',
    ),
    MemoryConcert(
      id: 'concert-5120',
      title: '골든 아워 페스타',
      artist: 'TIMO BAND',
      date: '2026.12.05',
      venue: '인천 메모리 돔',
      poster: 'assets/demo/stage_gold.png',
      videoUrl: 'assets/videos/official_demo.mp4',
    ),
    MemoryConcert(
      id: 'concert-6144',
      title: '카운트다운 스테이지',
      artist: 'TIMO CREW',
      date: '2026.12.31',
      venue: '올림픽 메모리 파크',
      poster: 'assets/demo/stage_pink.png',
      videoUrl: 'assets/videos/official_demo.mp4',
    ),
  ];
}

class HttpMemoryConcertApi implements MemoryConcertApi {
  HttpMemoryConcertApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  static const concertsPath = '/api/v1/collectibles/concerts';

  final Dio _dio;

  @override
  Future<List<MemoryConcert>> getConcerts() async {
    try {
      final response = await _dio.get<dynamic>(concertsPath);
      final body = response.data;
      if (body is! List) {
        throw const ApiException('공연 정보를 불러오지 못했어요.');
      }
      return body
          .cast<Map<String, dynamic>>()
          .map(
            (json) => MemoryConcert(
              id: json['concertId'] as String,
              title: json['title'] as String,
              artist: json['artist'] as String,
              date: json['date'] as String,
              venue: json['venue'] as String,
              // 포스터·영상은 저장소 key 로 온다. 앱이 읽을 절대 주소로 바꾼다.
              poster: ApiClient.imageUrl(json['thumbnailUrl'] as String?) ?? '',
              videoUrl: json['videoUrl'] as String,
            ),
          )
          .toList();
    } on DioException catch (e) {
      throw ApiException.from(e);
    }
  }
}
