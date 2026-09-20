import '../models/concert_summary.dart';

/// 공연 선택 화면이 서버에 요청하는 일.
///
/// 화면은 이 인터페이스만 안다. 앱에서는 `HttpConcertApi` 가 실제 서버에
/// 요청하고, 서버 없는 실행과 테스트는 `MockConcertApi` 를 쓴다. `app.dart`
/// 가 고른다 — 스캔·인증 API 와 같은 방식이다.
///
/// 반환 규칙: 성공하면 목록을, 실패(네트워크·서버 오류)는 `ApiException` 으로
/// 던진다. 결과가 없는 것은 실패가 아니라 빈 목록이다.
abstract class ConcertApi {
  /// 검표할 수 있는 공연 목록.
  ///
  /// [keyword] 를 주면 공연명 부분 일치로 서버가 걸러 준다. 비었거나 null 이면
  /// 조건 없이 받아 온다. 순서는 서버가 정한 대로 오고, 게이트에 맞게 다시
  /// 늘어놓는 일은 `ConcertSummary.sortedForGate` 가 한다.
  Future<List<ConcertSummary>> findAll({String? keyword});
}
