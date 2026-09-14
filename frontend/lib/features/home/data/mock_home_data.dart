import '../models/artist_summary.dart';

/// 서버 API 가 아직 없는 홈 섹션의 목업 데이터.
///
/// 공연 두 줄(오픈 임박 · 인기 공연)과 배너는 서버에서 받아 오므로 여기 없다.
/// 인기 아티스트만 남았다 — `HomeApi.fetchPopularArtists` 의 서버 구현이
/// 아티스트 API 가 생기기 전까지 이 값을 돌려준다. API 가 붙으면 이 클래스를
/// 지운다.
class MockHomeData {
  MockHomeData._();

  /// 시안의 원형 목록 순서. 마지막 '더보기' 칸은 데이터가 아니라 화면이 그린다.
  static const artists = <ArtistSummary>[
    ArtistSummary(name: '김준수'),
    ArtistSummary(name: '옥주현'),
    ArtistSummary(name: '검정치마'),
    ArtistSummary(name: '정명훈'),
    ArtistSummary(name: '아이유'),
    ArtistSummary(name: '박보검'),
    ArtistSummary(name: '페기구'),
  ];
}
